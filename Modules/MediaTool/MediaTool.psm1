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
    $sources | ForEach-Object {
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
    $script:files | ForEach-Object {
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
        # Return file details for the specified edition
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Edition -eq $Edition }
    } else {
        # Return file details for all editions
        $script:files | Where-Object { $_.Version -eq $Product -and $_.Architecture -eq $Architecture -and $_.Language -eq $Language -and $_.Media -eq $Media }
    }
}

function Get-MediaToolUSB {
    [CmdletBinding()]
    param(
    )

    # Return a list of removable media
    Get-Volume | Where-Object { $_.DriveType -eq "Removable" }
}

function New-MediaToolMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $Product,
        [Parameter(Mandatory=$true)] [string] $Architecture,
        [Parameter(Mandatory=$true)] [string] $Language,
        [Parameter(Mandatory=$true)] [string] $Media,
        [Parameter(Mandatory=$false)] [string] $Edition = "",
        [switch] $NoPrompt,
        [switch] $Recompress,
        [Parameter(Mandatory=$false)] [string] $Destination = [Environment]::GetFolderPath("mydocuments"),
        [Parameter(Mandatory=$false)] [string] $DownloadLocation = [Environment]::GetFolderPath("mydocuments"),
        [Parameter(Mandatory=$false)] [string] $Label = "Oofhours"
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
    
    # Destination could be USB or ISO.  Figure out which.
    $drive = Get-Volume -DriveLetter $Destination.Substring(0, 1)
    $createISO = $false
    $createUSB = $false
    if (-not ($Destination.EndsWith(":"))) {
        $createISO = $true
    } else {
        # For USB, make sure it's a drive letter
        if ($Destination.Length -ne 2) {
            throw "You must specify a removable drive letter with a colon, e.g. 'D:'"
        }
        # For USB, make sure the volume is removable
        if ($drive.DriveType -ne 'Removable') {
            throw "You must specify a removable drive"
        }
        if ($drive.Size -eq 0) {
            Write-Warning "Removable drive size cannot be determined."
        } else {
            $sizeGB = [math]::Round($drive.Size / 1024 / 1024 / 1024, 1)
            Write-Host "Removable volume size: $sizeGB GB"
        }
        $createUSB = $true
    }
    
    # Download the file if it doesn't already exist
    $esdDest = Join-Path -Path $DownloadLocation -ChildPath $currentFile.FileName
    if (-not (Test-Path $esdDest)) {

        # Check to see if we have enough disk space on the destination drive
        $vol = Get-Volume -FilePath $DownloadLocation
        if ($null -ne $vol) {
            if ([Int64]$currentFile.Size -gt $vol.SizeRemaining) {
                Write-Host "Insufficient space to download ESD file"
                return
            }
        }

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
            Write-Host "Download of the ESD failed."
            return
        }

    } else {
        Write-Verbose "ESD file $esdDest already exists, will use it."
    }

    # Make sure the ESD file contains the specified image.
    if ($Edition -ne "") {
        $imageInfo = Get-WimFileImagesInfo -WimFilePath $esdDest | Where-Object { $_.ImageEditionId -ieq $currentFile.Edition }
        if ($null -eq $imageInfo) {
            Write-Host "The downloaded ESD file does not contain an image for edition $($currentFile.Edition), unable to create ISO."
            Get-WimFileImagesInfo -WimFilePath $esdDest | Select-Object ImageEditionID | Out-Host
            return
        }
    } else {
        $imageInfo = Get-WimFileImagesInfo -WimFilePath $esdDest | Where-Object { $_.ImageIndex -gt 3 }
    }

    # For media, we'll put the content directly on the media.  For ISO, we need a temporary folder.
    if ($createISO)
    {
        # Create a folder for the extracted content
        $working = New-TemporaryDirectory
    } else {
        # Format the media to get rid of anything already there. Use the same drive letter and volume size
        Write-Host "Formatting volume $Destination as FAT32"
        $bootVolume = Format-Volume -DriveLetter $Destination.Substring(0, 1) -FileSystem FAT32 -NewFileSystemLabel $Label -ErrorAction SilentlyContinue
        if ($null -eq $bootVolume) {
            Write-Host "Format failed, assuming drive is greater than 32GB, partitioning and formatting to 32GB"
            # Partition it
            $disk = $drive | Get-Partition | Get-Disk | Select-Object -Unique
            if ($null -eq $disk) {
                throw "Unable to locate disk for drive $Destination"
            }
            Clear-Disk -Number $disk.Number -RemoveData -RemoveOEM -Confirm:$false
            Initialize-Disk -Number $disk.Number -PartitionStyle MBR -ErrorAction SilentlyContinue
            $bootPart = New-Partition -DiskNumber $disk.Number -AssignDriveLetter -Size 32GB
            $bootVolume = Format-Volume -DriveLetter $bootPart.DriveLetter -FileSystem FAT32 -NewFileSystemLabel $Label -Force
            if ($null -eq $bootVolume) {
                throw "Unable to format a 32GB partition on drive"
            }
        }
        # Use the media
        $working = $Destination
    }

    # For USB, put the temporary install.wim outside of the working folder
    if ($createUSB) {
        $wimPath = "$($env:TEMP)\install.wim"
    } else {
        $wimPath =  "$working\sources\install.wim"
    }

    # Apply the first image into that folder
    Write-Host "Applying image index 1 to working folder"
    Expand-WindowsImage -ImagePath $esdDest -Index 1 -ApplyPath $working
    
    # Extract the third image (Windows PE + Setup) as boot.wim into the folder
    Write-Host "Applying image index 3 (PE + setup) to working folder"
    Export-WindowsImage -SourceImagePath $esdDest -SourceIndex 3 -DestinationImagePath "$working\sources\boot.wim"  -DestinationName "Microsoft Windows Setup" -Setbootable -CompressionType Maximum
    
    # Extract the appropriate OS image into the folder as install.wim
    if ($Edition -ne "") {
        Write-Host "Exporting Windows $($imageInfo.ImageEditionId) image (index $($imageInfo.ImageIndex))"
        if ($Recompress) {
            Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $imageInfo.ImageIndex -DestinationImagePath $wimPath -CompressionType Maximum
        } else {
            Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $imageInfo.ImageIndex -DestinationImagePath $wimPath
        }
    } else {
        # Export all the images
        $imageInfo | ForEach-Object {
            Write-Host "Exporting Windows $($imageInfo.ImageEditionId) image (index $($_.ImageIndex))"
            if ($Recompress) {
                Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $_.ImageIndex -DestinationImagePath $wimPath -CompressionType Maximum
            } else {
                Export-WindowsImage -SourceImagePath $esdDest -SourceIndex $_.ImageIndex -DestinationImagePath $wimPath
            }
        }
    }

    # For media, split the install.wim.  Otherwise, capture an ISO.
    if ($createUSB) {
        Split-WindowsImage -ImagePath $wimPath -FileSize 4000 -SplitImagePath  "$working\sources\install.swm"
        Remove-Item $wimPath
        Write-Host "Media created successfully on $Destination drive."
    } else {
        # Capture the ISO
        Write-Host "Capturing ISO"
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