$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')
. (Join-Path $scriptDir 'ImageValidation.ps1')
. (Join-Path $scriptDir 'Metadata.ps1')
. (Join-Path $scriptDir 'API.ps1')

function Invoke-ImageProcessing {
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory=$true)]
        [int]$FileIndex,
        [Parameter(Mandatory=$true)]
        [int]$TotalFiles
    )

    Write-Log "Starting Invoke-ImageProcessing for $($File.Name)" -Level Info -Component "Processing"
    Write-Host "`n=== Processing File $FileIndex of $TotalFiles ===" -ForegroundColor Green
    Write-Log "Starting processing for file: $($File.Name)" -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
    
    if (-not $File.Exists) {
        Write-Log "File no longer exists: $($File.FullName)" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        return
    }

    $fileSizeMB = [math]::Round($File.Length/1MB, 2)
    Write-Log "File size: $fileSizeMB MB" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
    Write-Log "Last modified: $($File.LastWriteTime)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"

    try {
        Write-Log "Validating image..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        if (-not (Test-IsImage -FilePath $File.FullName -FileIndex $FileIndex -TotalFiles $TotalFiles)) {
            throw "Invalid image file"
        }

        $metadata = Get-ImageMetadata -Path $File.FullName
        if ($metadata) {
            Write-Log "Metadata extracted successfully" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        }

        Write-Log "Converting image to Base64..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        try {
            $imageBytes = [IO.File]::ReadAllBytes($File.FullName)
            $imageBase64 = [Convert]::ToBase64String($imageBytes)
            $base64SizeMB = [math]::Round($imageBase64.Length/1MB, 2)
            Write-Log "Base64 conversion complete ($base64SizeMB MB)" -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
            
            if ($base64SizeMB -gt $Config.API.MaxPayloadSizeMB) {
                throw "Base64 conversion resulted in too large payload: $base64SizeMB MB"
            }
        }
        catch {
            throw "Failed to convert image to Base64: $($_.Exception.Message)"
        }

        Write-Log "Requesting image analysis..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        $keywords = (Invoke-LlamaAPI `
            -Model $Config.API.Models.ImageAnalysis `
            -Prompt @"
Analyze this image in detail and extract key information:
1. Main subjects/objects
2. Actions/activities if any
3. Notable colors or visual elements
4. Any visible text or numbers
5. Setting/environment
6. Distinctive features
7. Time of day/season if apparent
8. Emotional tone/mood
9. Technical aspects (if relevant)
10. Cultural elements (if any)

Output only a JSON array of keywords: {keywords: string[]}
Requirements:
- Keep each keyword concise (1-3 words max)
- Include both general and specific terms
- Prioritize unique/distinctive features
- Include temporal indicators if present
- Note technical qualities if relevant
"@ `
            -AdditionalData @{ 
                images = @($imageBase64)
                metadata = @{
                    properties = @($metadata.Keys | ForEach-Object {
                        @{
                            id = $_.ToString()
                            value = $metadata[$_].Value.ToString()
                            type = $metadata[$_].Type.ToString()
                        }
                    })
                }
            } `
            -FileIndex $FileIndex `
            -TotalFiles $TotalFiles).keywords

        if (-not $keywords -or $keywords.Count -eq 0) {
            throw "No keywords generated from image analysis"
        }
        Write-Log "Generated $($keywords.Count) keywords:" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        foreach ($keyword in $keywords) {
            Write-Log "  - $keyword" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        }

        $datePrefix = ""
        if ($Config.Processing.AddDatePrefix) {
            $dateTaken = Get-ExifDateTaken -Path $File.FullName
            if ($dateTaken) {
                $datePrefix = $dateTaken.ToString("yyyy-MM-dd_HH-mm-ss_")
            }
        }

        Write-Log "Generating new filename..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        $newFilename = (Invoke-LlamaAPI `
            -Model $Config.API.Models.TextGeneration `
            -Prompt @"
Create a descriptive filename (max $($Config.Processing.FilenameMaxLength - $datePrefix.Length) chars) using:
Original name: '$($File.Name)'
Keywords: $($keywords -join ', ')
Metadata: $(if ($metadata) { "Available" } else { "Not available" })

Requirements:
1. Keep file extension: $($File.Extension)
2. Use underscores for spaces
3. Include most distinctive keyword
4. Maintain readability
5. Start with most important aspect
6. Include technical specs if relevant
7. Ensure uniqueness
8. Remove any random random letter
9. Describe the image with the keywords provided the best way possible
10. Keep the ending file exstention format '.$($File.Extension)'

Output JSON: {filename: string}
"@ `
            -FileIndex $FileIndex `
            -TotalFiles $TotalFiles).filename

        if (-not $newFilename) {
            throw "Failed to generate new filename"
        }

        $newFilename = $datePrefix + $newFilename

        if ($newFilename -match '[<>:"/\\|?*]') {
            throw "Generated filename contains invalid characters: $newFilename"
        }

        Write-Log "New filename generated: $newFilename" -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"

        $paths = @{
            Renamed = Join-Path -Path (Join-Path -Path $File.Directory.FullName -ChildPath "renamed") -ChildPath $newFilename
            Original = Join-Path -Path (Join-Path -Path $File.Directory.FullName -ChildPath "original") -ChildPath $File.Name
        }

        Write-Log "Creating required directories..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        foreach ($dir in ($paths.Values | Where-Object { $_ } | Split-Path -Parent | Select-Object -Unique)) {
            if (-not (Test-Path $dir)) {
                try {
                    New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
                    Write-Log "Created directory: $dir" -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
                }
                catch {
                    throw "Failed to create directory $dir : $($_.Exception.Message)"
                }
            }
        }

        Write-Log "Copying file to renamed folder..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        try {
            Copy-Item -Path $File.FullName -Destination $paths.Renamed -Force -ErrorAction Stop
            Write-Log "File copied successfully" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        }
        catch {
            throw "Failed to copy file to renamed folder: $($_.Exception.Message)"
        }
        $exifDateTaken = Get-ExifDateTaken -Path $file.FullName
        if ($exifDateTaken) {
            try {
                [System.IO.File]::SetCreationTime($paths.Renamed, $exifDateTaken)
                Write-Log "Creation time set to EXIF DateTaken: $exifDateTaken" -Level Info -Component "Processing"
            } catch {
                Write-Log "Failed to set creation time for file: $paths.Renamed" -Level Warning -Component "Processing"
            }
        }

        if ($Config.Processing.PreserveMetadata -and $metadata) {
            Write-Log "Preserving metadata..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
            try {
                if ($metadata.ContainsKey(36867)) {
                    $exifDate = [datetime]::ParseExact(
                        $metadata[36867].Value,
                        "yyyy:MM:dd HH:mm:ss",
                        $null
                    )
                    Set-ExifDateTaken -Path $paths.Renamed -DateTime $exifDate
                    [System.IO.File]::SetCreationTime($paths.Renamed, $exifDate)
                    [System.IO.File]::SetLastWriteTime($paths.Renamed, $exifDate)
                    [System.IO.File]::SetLastAccessTime($paths.Renamed, $exifDate)

                    Write-Log "Metadata timestamps preserved" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
                }
            }
            catch {
                Write-Log "Failed to preserve metadata: $($_.Exception.Message)" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
            }
        }

        Write-Log "Moving original file..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        try {
            Move-Item -Path $File.FullName -Destination $paths.Original -Force -ErrorAction Stop
            Write-Log "Original file moved successfully" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        }
        catch {
            throw "Failed to move original file: $($_.Exception.Message)"
        }

        Write-Log "Successfully processed: $($File.Name) to $newFilename" -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        Write-Host "=== File Processing Complete ===`n" -ForegroundColor Green
    }
    catch {
        Write-Log "Processing failed: $($_.Exception.Message)" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        Write-Host "=== File Processing Failed ===`n" -ForegroundColor Red
        
        if (Test-Path $paths.Renamed) {
            Write-Log "Attempting to clean up partial renamed file..." -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
            try {
                Remove-Item -Path $paths.Renamed -Force
                Write-Log "Cleaned up partial renamed file" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
            }
            catch {
                Write-Log "Failed to clean up partial renamed file: $($_.Exception.Message)" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
            }
        }
    }
}
