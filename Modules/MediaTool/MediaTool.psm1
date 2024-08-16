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

    # Add a version and media type to each
    $script:files | % {
        $build = $_.FileName.Substring(0,5)
        switch ($build)
        {
            "19041" { $version = "Windows 10 (2004)" }
            "19042" { $version = "Windows 10 (20H2)" }
            "19043" { $version = "Windows 10 (21H1)" }
            "19044" { $version = "Windows 10 (21H2)" }
            "19045" { $version = "Windows 10 (22H2)" }
            "19046" { $version = "Windows 10 (23H2)" }
            "22000" { $version = "Windows 11 (21H2)" }
            "22621" { $version = "Windows 11 (22H2)" }
            "22631" { $version = "Windows 11 (23H2)" }
            "26100" { $version = "Windows 11 (24H2)" }
            default { $version = "Windows ($build)"}
        }
        $_ | Add-Member -NotePropertyName "Version" -NotePropertyValue $version

        if ($_.FileName.Contains("CLIENTCONSUMER_RET")) {
            $media = "CLIENTCONSUMER_RET"
        }
        elseif ($_.FileName.Contains("CLIENTCHINA_RET")) {
            $media = "CLIENTCHINA_RET"
        }
        elseif ($_.FileName.Contains("CLIENTBUSINESS_VOL")) {
            $media = "CLIENTBUSINESS_VOL"
        } else {
            $media = "Unknown"
        }
        $_ | Add-Member -NotePropertyName "Media" -NotePropertyValue $media

    }

    # Log the number of images
    Write-Host "$($script:files.count) images are available."
}

function Get-MediaToolList {
    [CmdletBinding()]
    param(
        [switch] $All,
        [Parameter()] [string] $Product = "",
        [Parameter()] [string] $Architecture = "",
        [Parameter()] [string] $Language = "",
        [Parameter()] [string] $Media = "",
        [Parameter()] [string] $Edition = ""
    )

    # Filter and return a summarized list of values based on the first blank value
    if ($All) {
        # Return everything
        $script:files
    } elseif ($Product -eq "") {
        $script:files | Select-Object -Property Version -Unique
    } elseif ($Architecture -eq "") {
        $script:files | Where-Object { $_.Version -eq $Product } | Select-Object -Property Architecture -Unique
    } elseif ($Language -eq "") {
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture } | Select-Object -Property Language -Unique
    } elseif ($Media -eq "") {
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language } | Select-Object -Property Media -Unique
    } elseif ($Edition -ne "") {
        # Return file details for the specified editiion
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Edition -eq $Edition }
    } else {
        # Return file details for all editions
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Media -eq $Media }
    }
}

function Get-MediaToolISO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $Product,
        [Parameter(Mandatory=$true)] [string] $Architecture,
        [Parameter(Mandatory=$true)] [string] $Language,
        [Parameter(Mandatory=$true)] [string] $Media,
        [Parameter(Mandatory=$false)] [string] $Edition = "",
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

    # Make sure OSCDImg.exe is present
    if (-not (Test-Path "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")) {
        Write-Host "Unable to find OSCDIMG.EXE which is needed to create an ISO."
        Write-Host "Expected path: $($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    }

    # Get the specific file object
    if ($edition -eq "") {
        $currentFile = $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Media -eq $Media } | Select-Object -First 1
        if ($null -eq $currentFile) {
            Write-Host "No image found for product=$Product arch=$Architecture lang=$Language media=$Media"
            return
        }
    } else {
        $currentFile = $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Media -eq $Media -and $_.Edition -eq $Edition }
        if ($null -eq $currentFile) {
            Write-Host "No image found for product=$Product arch=$Architecture lang=$Language media=$Media edition=$Edition"
            return
        }
    }

    # Download the file if it doesn't already exist
    $esdDest = Join-Path -Path $Destination -ChildPath $currentFile.FileName
    if (-not (Test-Path $esdDest)) {

        # Let's make sure the file is accessible.  This may be required with the MS CDN.
        try {
            # Read the header (208 bytes)
            $request = [System.Net.WebRequest]::Create($currentFile.FilePath)
            $request.Method = "GET"
            $request.AddRange("bytes", 0, 208)
            $reader = New-Object System.IO.BinaryReader($request.GetResponse().GetResponseStream())
            $bytes = New-Object Byte[](208)
            $reader.Read($bytes, 0, 207) | Out-Null

            # Check the magic header
            if ([System.Text.Encoding]::ASCII.GetString($bytes[0..4]) -ne "MSWIM") {
               throw "Invalid WIM/ESD file, incorrect magic string in header"
            }
        } catch {
            Write-Verbose "Unexpected error checking validity of URL $($currentFile.FilePath): $_"
        }

        # Make sure we don't have any suspended BITS jobs
        Get-BitsTransfer | Where-Object { $_.DisplayName -eq "Oofhours Media Tool" } | Remove-BitsTransfer

        # Use BITS to to the actual download, since that reports progress
        Write-Verbose "Downloading ESD file to $esdDest"
        Start-BitsTransfer -Source $currentFile.FilePath -Destination $esdDest -Priority Foreground -DisplayName "Oofhours Media Tool"
        if (-not (Test-Path $esdDest)) {
            Write-Verbose "Download of the ESD failed."
            return
        }

    } else {
        Write-Verbose "ESD file $esdDest already exists, will use it."
    }

    # Make sure the ESD file contains the specified image.
    if ($Edition -ne "") {
        $imageInfo = Get-WimFileImagesInfo -WimFilePath $esdDest | Where-Object { $_.ImageEditionId -ieq $currentFile.Edition }
        if ($null -eq $imageInfo) {
            Write-Verbose "The downloaded ESD file does not contain an image for edition $($currentFile.Edition), unable to create ISO."
            Get-WimFileImagesInfo -WimFilePath $esdDest | Select ImageEditionID | Out-Host
            return
        }
    } else {
        $imageInfo = Get-WimFileImagesInfo -WimFilePath $esdDest | Where-Object { $_.ImageIndex -gt 3 }
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
    if ($Edition -ne "") {
        Write-Verbose "Exporting Windows $($imageInfo.ImageEditionId) image (index $($imageInfo.ImageIndex))"
        if ($Recompress) {
            Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $imageInfo.ImageIndex -DestinationImagePath "$working\sources\install.wim" -CompressionType Maximum
        } else {
            Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $imageInfo.ImageIndex -DestinationImagePath "$working\sources\install.wim"
        }
    } else {
        # Export all the images
        $imageInfo | ForEach-Object {
            Write-Verbose "Exporting Windows $($imageInfo.ImageEditionId) image (index $($_.ImageIndex))"
            if ($Recompress) {
                Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $_.ImageIndex -DestinationImagePath "$working\sources\install.wim" -CompressionType Maximum
            } else {
                Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $_.ImageIndex -DestinationImagePath "$working\sources\install.wim"
            }
        }
    }

    # Capture the ISO
    Write-Verbose "Capturing ISO"
    $esdInfo = Get-Item $esdDest
    if ($Edition -eq "") {
        $isoDest = Join-Path -Path $Destination -ChildPath "$($esdInfo.BaseName).iso"
    } else {
        $isoDest = Join-Path -Path $Destination -ChildPath "$($esdInfo.BaseName)_$($currentFile.Edition).iso"
    }
    Push-Location "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
    if ($noPrompt) {
        & "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" "-lWindowsSetup"'-o' '-u2' '-m' '-udfver102' "-bootdata:1#pEF,e,befisys_noprompt.bin" "$working" "$isoDest" | Out-Null
    } else {
        & "$($kitsRoot)Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" "-lWindowsSetup"'-o' '-u2' '-m' '-udfver102' "-bootdata:1#pEF,e,befisys.bin" "$working" "$isoDest" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Unexpected return code from OSCDIMG.EXE, rc = $LASTEXITCODE"
    } else {
        Write-Host "$isoDest created."
    }
    Pop-Location

    # Clean up the temporary folder
    Remove-Item $working -Recurse -Force
}

function Test-MediaToolFile {
    # Make sure all the files are accessible
    Get-MediaToolList -All | Select-Object -Property FilePath -Unique | ForEach-Object {
        $current = $_
        try {
            $resp = Invoke-WebRequest -Uri $current.FilePath -Method HEAD -UseBasicParsing
            if ($resp.StatusCode -ne 200) {
                $current.FilePath,$resp
            }
        } catch {
            $current.FilePath, $_
        }
    }
}