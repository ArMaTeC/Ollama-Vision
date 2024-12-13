$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')

function Get-ImageMetadata {
    param (
        [Parameter(Mandatory=$True)]
        [string]$Path
    )

    Write-Log "Starting Get-ImageMetadata for $Path" -Level Debug -Component "Metadata"
    Write-Log "Processing file path: $Path" -Level Debug -Component "Metadata"

    $FileItem = $null
    $FileStream = $null
    $Img = $null
    $metadata = @{}

    try {
        Write-Log "Attempting to resolve path: $Path" -Level Debug -Component "Metadata"
        $FileItem = Resolve-Path $Path -ErrorAction Stop
        if (-not $FileItem) {
            throw "Failed to resolve path: $Path"
        }
        Write-Log "Path resolved successfully: $Path" -Level Debug -Component "Metadata"

        $ImageFile = (Get-ChildItem $FileItem.Path -ErrorAction Stop).FullName
        Write-Log "Resolved image file path: $ImageFile" -Level Debug -Component "Metadata"

        Write-Log "Attempting to open file stream for image file: $ImageFile" -Level Debug -Component "Metadata"
        $FileStream = New-Object System.IO.FileStream(
            $ImageFile, 
            [System.IO.FileMode]::Open, 
            [System.IO.FileAccess]::Read, 
            [System.IO.FileShare]::Read
        )
        Write-Log "File stream opened successfully for image file: $ImageFile" -Level Debug -Component "Metadata"
        
        Write-Log "Attempting to create image from file stream" -Level Debug -Component "Metadata"
        $Img = [System.Drawing.Image]::FromStream($FileStream)
        Write-Log "Image created successfully from file stream" -Level Debug -Component "Metadata"
        
        foreach ($propId in $Img.PropertyIdList) {
            try {
                Write-Log "Attempting to get property item for property ID: $propId" -Level Debug -Component "Metadata"
                $prop = $Img.GetPropertyItem($propId)
                Write-Log "Property item retrieved successfully for property ID: $propId" -Level Debug -Component "Metadata"
                $value = switch ($prop.Type) {
                    1 { [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0) }
                    2 { [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0) }
                    3 { [BitConverter]::ToUInt16($prop.Value, 0) }
                    4 { [BitConverter]::ToUInt32($prop.Value, 0) }
                    5 { 
                        $numerator = [BitConverter]::ToUInt32($prop.Value, 0)
                        $denominator = [BitConverter]::ToUInt32($prop.Value, 4)
                        if ($denominator -ne 0) { $numerator / $denominator } else { 0 }
                    }
                    default { "Unknown type: $($prop.Type)" }
                }
                
                $metadata[$propId] = @{
                    Value = $value
                    Type = $prop.Type
                    Len = $prop.Len
                }
                Write-Log "Metadata added for property ID: $propId" -Level Debug -Component "Metadata"
            }
            catch {
                Write-Log "Failed to read property $propId : $($_.Exception.Message)" -Level Warning -Component "Metadata"
            }
        }

        $commonTags = @{
            DateTimeOriginal = 36867
            Make = 271
            Model = 272
            ISOSpeed = 34855
            ExposureTime = 33434
            FNumber = 33437
            FocalLength = 37386
            GPSLatitude = 2
            GPSLongitude = 4
        }

        foreach ($tag in $commonTags.GetEnumerator()) {
            if ($metadata.ContainsKey($tag.Value)) {
                Write-Log "Found $($tag.Key): $($metadata[$tag.Value].Value)" -Level Debug -Component "Metadata"
            }
        }

        return $metadata
    }
    catch {
        Write-Log "Failed to read metadata: $($_.Exception.Message)" -Level Warning -Component "Metadata"
        return $null
    }
    finally {
        if ($Img) { 
            Write-Log "Disposing image object" -Level Debug -Component "Metadata"
            $Img.Dispose() 
        }
        if ($FileStream) { 
            Write-Log "Closing and disposing file stream" -Level Debug -Component "Metadata"
            $FileStream.Close()
            $FileStream.Dispose()
        }
    }
}

function Get-ExifDateTaken {
    param (
        [Parameter(Mandatory=$True)]
        [Alias('FullName', 'FileName')]
        $Path
    )

    Write-Log "Initiating Get-ExifDateTaken for $Path" -Level Debug -Component "EXIF"

    $FileItem = Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ResolveError
    if ($ResolveError) {
        Write-Log "Invalid path '$Path' ($($ResolveError[0].CategoryInfo.Category))" -Level Error -Component "EXIF"
        return $null
    }

    $ImageFile = (Get-ChildItem $FileItem.Path).FullName
    Write-Log "Image file path resolved: $ImageFile" -Level Debug -Component "EXIF"

    $DateTaken = $null

    try {
        Write-Log "Attempting to open file stream for $ImageFile" -Level Debug -Component "EXIF"
        $FileStream = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        Write-Log "File stream opened successfully for $ImageFile" -Level Debug -Component "EXIF"
        $Img = [System.Drawing.Image]::FromStream($FileStream)
        try {
            if ($Img.PropertyIdList -contains 36867) {
                Write-Log "EXIF DateTimeOriginal property found in $ImageFile" -Level Debug -Component "EXIF"
                $ExifDT = $Img.GetPropertyItem(36867)
                if ($null -eq $ExifDT.Value) {
                    Write-Log "EXIF DateTimeOriginal value is null. Fallback to file creation time." -Level Warning -Component "EXIF"
                    $FileCreationTime = (Get-Item $ImageFile).CreationTime
                    $DateTaken = $FileCreationTime
                } else {
                    $ExifDtString = [System.Text.Encoding]::ASCII.GetString($ExifDT.Value).TrimEnd([char]0)
                    try {
                        $DateTaken = [datetime]::ParseExact($ExifDtString, "yyyy:MM:dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
                        Write-Log "DateTimeOriginal extracted: $DateTaken" -Level Debug -Component "EXIF"
                    } catch {
                        Write-Log "Failed to parse EXIF DateTimeOriginal for file '$ImageFile'. Error: $($_.Exception.Message)" -Level Error -Component "EXIF"
                        $DateTaken = $null
                    }
                }
            } else {
                Write-Log "EXIF DateTimeOriginal property not found. Fallback to file creation time." -Level Warning -Component "EXIF"
                $FileCreationTime = (Get-Item $ImageFile).CreationTime
                $DateTaken = $FileCreationTime
            }
        } catch {
            Write-Log "Parsing EXIF DateTimeOriginal failed for file '$ImageFile'. Error: $($_.Exception.Message)" -Level Error -Component "EXIF"
        }
    } catch {
        Write-Log "Reading EXIF data failed for file '$ImageFile'. Error: $($_.Exception.Message)" -Level Error -Component "EXIF"
    } finally {
        if ($Img) { 
            Write-Log "Disposing image object for $ImageFile" -Level Debug -Component "EXIF"
            $Img.Dispose() 
        }
        if ($FileStream) { 
            Write-Log "Closing file stream for $ImageFile" -Level Debug -Component "EXIF"
            $FileStream.Close() 
        }
    }
    if ($null -eq $DateTaken) {
        # Check if the creation time is the same as today's date or does not match the folder name
        $today = Get-Date -Format "yyyy:MM:dd HH:mm:ss"
        Write-Log "Today's date: $today" -Level Debug -Component "EXIF"
    
        # Extract the year and month from the folder path
        $folderPathParts = $Path.Split("\")
        $year = $folderPathParts[-3]
        $month = $folderPathParts[-2]
        $folderDate = "${year}:${month}:01 00:00:00"
    
        Write-Log "Folder date: $folderDate" -Level Debug -Component "EXIF"
        if ($null -eq $DateTaken -or $DateTaken.ToString("yyyy:MM:dd HH:mm:ss") -eq $today -or $DateTaken.ToString("yyyy:MM:dd HH:mm:ss") -ne $folderDate) {
            Write-Log "Creation time is the same as today's date or does not match the folder name. Favoring the folder date." -Level Debug -Component "EXIF"
            try {
                $DateTaken = [datetime]::ParseExact($folderDate, "yyyy:MM:dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
                Write-Log "Parsed folder date: $DateTaken" -Level Debug -Component "EXIF"
            } catch {
                Write-Log "Failed to parse folder date for file '$ImageFile'. Error: $($_.Exception.Message)" -Level Error -Component "EXIF"
                $DateTaken = $null
            }
        }
    }
    return $DateTaken
}
Function Set-ExifDateTaken {

    [CmdletBinding(SupportsShouldProcess=$True)]
    Param (
        [Parameter(Mandatory=$True)]
        [Alias('FullName', 'FileName')]
        $Path,
    
        [Parameter(Mandatory=$True)]
        [string]$DateTime
    )
    
    Begin {
        Set-StrictMode -Version Latest
        If ($PSVersionTable.PSVersion.Major -lt 3) {
            Add-Type -AssemblyName "System.Drawing"
        }
    }
    
    Process {
        # Read the current file and extract the Exif DateTaken property
        $ImageFile = (Get-ChildItem $Path).FullName

        Try {
            $FileStream = New-Object System.IO.FileStream($ImageFile,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read,
                1024,     # Buffer size
                [System.IO.FileOptions]::SequentialScan
            )
            $Img = [System.Drawing.Imaging.Metafile]::FromStream($FileStream)
            $ExifDT = $Img.GetPropertyItem('36867')
        }
        Catch {
            Write-Log "Check $ImageFile is a valid image file ($_)" -Level Warning -Component "EXIF"
            If ($Img) { $Img.Dispose() }
            If ($FileStream) { $FileStream.Close() }
            Break
        }

        # Convert to a string, changing slashes back to colons in the date.  Include trailing 0x00…
        $ExifTime = $DateTime + "`0"

        # Overwrite the EXIF DateTime property in the image and set
        $ExifDT.Value = [Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)
        $Img.SetPropertyItem($ExifDT)

        # Create a memory stream to save the modified image…
        $MemoryStream = New-Object System.IO.MemoryStream

        Try {
            # Save to the memory stream then close the original objects
            # Save as type $Img.RawFormat  (Usually [System.Drawing.Imaging.ImageFormat]::JPEG)
            $Img.Save($MemoryStream, $Img.RawFormat)
        }
        Catch {
            Write-Log "Problem modifying image $ImageFile ($_)" -Level Warning -Component "EXIF"
            $MemoryStream.Close(); $MemoryStream.Dispose()
            Break
        }
        Finally {
            $Img.Dispose()
            $FileStream.Close()
        }

        # Update the file (Open with Create mode will truncate the file)

        If ($PSCmdlet.ShouldProcess($ImageFile, 'Set EXIF DateTaken')) {
            Try {
                $Writer = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Create)
                $MemoryStream.WriteTo($Writer)
            }
            Catch {
                Write-Log "Problem saving to $OutFile ($_)" -Level Warning -Component "EXIF"
                Break
            }
            Finally {
                If ($Writer) { $Writer.Flush(); $Writer.Close() }
                $MemoryStream.Close(); $MemoryStream.Dispose()
            }
        }
    } # End Process Block
    
    End {
        # There is no end processing…
    }
    
} # End Function