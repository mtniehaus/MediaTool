#region Internal utility

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    $newDir = New-Item -ItemType Directory -Path (Join-Path $parent $name)
    return $newDir.FullName
}

#endregion Internal utility

function Initialize-MediaTool {
    [CmdletBinding()]
    param(
    )

    # Get the latest files
    $script:files = @()
    $sources = @("https://go.microsoft.com/fwlink/?LinkId=2156292","https://go.microsoft.com/fwlink/?LinkId=841361")
    $sources | % {
        $tempDir = New-TemporaryDirectory
        # Download
        Write-Verbose "Downloading from $_"
        Invoke-WebRequest -Uri $_ -UseBasicParsing -OutFile "$tempDir\products.cab"
        # Extract
        $null = MkDir "$tempDir\manifests"
        Expand.exe -R "$tempDir\products.cab" "$tempDir\manifests" | Out-Null
        # Load
        $products = New-Object xml
        Get-ChildItem -Path "$tempDir\manifests\*.xml" | ForEach-Object {
            $products.Load($_.FullName)
            $script:files += $products.MCT.Catalogs.Catalog.PublishedMedia.Files.File
        }
        # Clean up 
        Remove-Item -Path $tempDir -Recurse -Force
    }

    # Add a version to each
    $script:files | % {
        switch ($_.FileName.Substring(0,5))
        {
            "19041" { $version = "Windows 10 (2004)" }
            "19042" { $version = "Windows 10 (20H2)" }
            "19043" { $version = "Windows 10 (21H1)" }
            "19044" { $version = "Windows 10 (21H2)" }
            "19045" { $version = "Windows 10 (22H2)" }
            "19046" { $version = "Windows 10 (23H2)" }
            "22000" { $version = "Windows 11 (21H2)" }
            "22621" { $version = "Windows 11 (22H2)" }
            default { $version = "Windows ($($_.FileName.Substring(0,5))"}
        }
        $_ | Add-Member -NotePropertyName "Version" -NotePropertyValue $version
    }

    # Log the number of images
    Write-Host "$($script:files.count) images are available."
}

function Get-MediaToolList {
    [CmdletBinding()]
    param(
        [Parameter()] [string] $Product = "",
        [Parameter()] [string] $Architecture = "",
        [Parameter()] [string] $Language = "",
        [Parameter()] [string] $Edition = ""
    )

    # Filter and return a summarized list of values based on the first blank value
    if ($Product -eq "") {
        $script:files | Select-Object -Property Version -Unique
    } elseif ($Architecture -eq "") {
        $script:files | Where-Object { $_.Version -eq $Product } | Select-Object -Property Architecture -Unique
    } elseif ($Language -eq "") {
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture } | Select-Object -Property Language -Unique
    } elseif ($Edition -eq "") {
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language } | Select-Object -Property Edition -Unique
    } else {
        # Return the file detail when we've got a full match
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Edition -eq $Edition }
    }
}

function Get-MediaToolISO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $Product,
        [Parameter(Mandatory=$true)] [string] $Architecture,
        [Parameter(Mandatory=$true)] [string] $Language,
        [Parameter(Mandatory=$true)] [string] $Edition,
        [switch] $NoPrompt,
        [switch] $Recompress,
        [Parameter(Mandatory=$false)] [string] $Destination = [Environment]::GetFolderPath("mydocuments")
    )

    # Find the ADK
    if (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots") {
        $kitsRoot = Get-ItemPropertyValue -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows Kits\Installed Roots" -Name KitsRoot10
    }
    elseif (Test-Path "HKLM:\Software\Microsoft\Windows Kits\Installed Roots") {
        $kitsRoot = Get-ItemPropertyValue -Path "HKLM:\Software\Microsoft\Windows Kits\Installed Roots" -Name KitsRoot10
    } else {
        Write-Host "The Assessment and Deployment Kit (ADK) is not installed.  This is required to create an ISO."
        return
    }
        
    # Get the specific file object
    $currentFile = $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Edition -eq $Edition }
    if ($null -eq $currentFile) {
        Write-Host "No image found for product=$Product arch=$Architecture lang=$Language edition=$Edition"
        return
    }

    # Download the file if it doesn't already exist
    $esdDest = "$destination\$($currentFile.FileName)"
    if (-not (Test-Path $esdDest)) {
        Write-Verbose "Downloading ESD file to $esdDest"
        Start-BitsTransfer -Source $currentFile.FilePath -Destination $esdDest -Priority Foreground
        if (-not (Test-Path $esdDest)) {
            Write-Verbose "Download of the ESD failed."
            return
        }
    } else {
        Write-Verbose "ESD file $esdDest already exists, will use it."
    }

    # Make sure the ESD file contains the specified image.
    $imageInfo = Get-WimFileImagesInfo -WimFilePath $esdDest | Where-Object { $_.ImageEditionId -ieq $currentFile.Edition }
    if ($null -eq $imageInfo) {
        Write-Verbose "The downloaded ESD file does not contain an image for edition $($currentFile.Edition), unable to create ISO."
        Get-WimFileImagesInfo -WimFilePath $esdDest | Select ImageEditionID | Out-Host
        return
    }
    
    # Create a folder for the extracted content
    $working = New-TemporaryDirectory
    
    # Apply the first image into that folder
    Write-Verbose "Applying image index 1 to working folder"
    Expand-WindowsImage -ImagePath $esdDest -Index 1 -ApplyPath $working
    
    # Extract the third image (Windows PE + Setup) as boot.wim into the folder
    Write-Verbose "Applying image index 3 (PE + setup) to working folder"
    Export-WindowsImage -SourceImagePath $esdDest -SourceIndex 3 -DestinationImagePath "$working\sources\boot.wim"  -DestinationName "Microsoft Windows Setup" -Setbootable -CompressionType Maximum
    
    # Extract the appropriate OS image into the folder as install.wim
    Write-Verbose "Exporting Windows image (index $($imageInfo.ImageIndex))"
    if ($Recompress) {
        Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $imageInfo.ImageIndex -DestinationImagePath "$working\sources\install.wim" -CompressionType Maximum
    } else {
        Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $imageInfo.ImageIndex -DestinationImagePath "$working\sources\install.wim"
    }

    # Capture the ISO
    Write-Verbose "Capturing ISO"
    $esdInfo = Get-Item $esdDest
    $isoDest = "$destination\$($esdInfo.BaseName)_$($currentFile.Edition).iso"
    Push-Location "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
    if ($noPrompt) {
        & "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" "-lWindowsSetup"'-o' '-u2' '-m' '-udfver102' "-bootdata:1#pEF,e,befisys_noprompt.bin" "$working" "$isoDest" | Out-Null
    } else {
        & "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" "-lWindowsSetup"'-o' '-u2' '-m' '-udfver102' "-bootdata:1#pEF,e,befisys.bin" "$working" "$isoDest" | Out-Null
    }
    Pop-Location
    Write-Verbose "$isoDest created."

    # Clean up the temporary folder
    Remove-Item $working -Recurse -Force
}