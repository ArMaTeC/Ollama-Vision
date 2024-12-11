function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        [int]$FileIndex = 0,
        [int]$TotalFiles = 0,
        [string]$Component = "Main",
        [switch]$NoConsole
    )
    
    # Early return if debug logging is disabled
    if ($Level -eq 'Debug' -and $Config.Logging.LogLevel -ne 'Debug') {
        return
    }
    
    try {
        # Format timestamp with high precision
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        
        # Build progress prefix if processing multiple files
        $prefix = if ($FileIndex -gt 0 -and $TotalFiles -gt 0) { 
            "[$FileIndex/$TotalFiles]" 
        } else { 
            "" 
        }
        
        # Define console colors for different log levels
        $color = switch ($Level) {
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Debug' { 'DarkGray' }  # DarkGray is easier on the eyes
            'Info' { 'White' }
            default { 'White' }
        }
        
        # Construct the log message with consistent formatting
        $logMessage = "{0} {1} [{2}] [{3}] {4}" -f $timestamp, $prefix, $Level.ToUpper(), $Component, $Message
        
        # Output to console unless suppressed
        if (-not $NoConsole) {
            Write-Host $logMessage -ForegroundColor $color
        }
        
        # Could add file logging here in the future
        # $logMessage | Out-File -Append -FilePath $Config.Logging.LogFile
    }
    catch {
        $errorMsg = "Failed to write log message. Error: $($_.Exception.Message)"
        Write-Warning $errorMsg
        
        # In case of critical failure, attempt to write to the Windows Event Log
        try {
            Write-EventLog -LogName Application -Source "PowerShell" -EntryType Error -EventId 1000 -Message $errorMsg
        }
        catch {
            # At this point we can't do much more than suppress the error
        }
    }
}

Write-Log "Script initialization starting..." -Level Info -Component "Init"

$Config = @{
    WorkingDirectory = Get-Location
    ExcludedFolders = @(
        "renamed",
        "original"
    )
    SupportedExtensions = @(
        ".jpg", 
        ".jpeg", 
        ".png"
    )

    API = @{
        Url = "http://localhost:11434/api/generate"
        Headers = @{
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        TimeoutSeconds = 60
        MaxRetries = 5
        RetryDelaySeconds = 3
        MaxPayloadSizeMB = 500
        Models = @{
            ImageAnalysis = "llama3.2-vision"
            TextGeneration = "gemma2"
        }
    }

    Logging = @{
        LogLevel = "Info"
    }

    Processing = @{
        PreserveMetadata = $true
        FilenameMaxLength = 100
        RandomizeOrder = $false
        MaxConcurrentFiles = [Math]::Min($env:NUMBER_OF_PROCESSORS, 8)
    }
}

Write-Log "Configuration object initialized" -Level Info -Component "Init"
Write-Log "Validating configuration..." -Level Info -Component "Config"

if (-not (Test-Path $Config.WorkingDirectory)) {
    Write-Log "Working directory does not exist: $($Config.WorkingDirectory)" -Level Error -Component "Config"
    throw "Working directory does not exist: $($Config.WorkingDirectory)"
}

if (-not $Config.API.Url) {
    Write-Log "API URL is not configured" -Level Error -Component "Config" 
    throw "API URL is not configured"
}

if (-not $Config.API.Models.ImageAnalysis -or -not $Config.API.Models.TextGeneration) {
    Write-Log "Required API models are not configured" -Level Error -Component "Config"
    throw "Required API models are not configured"
}

Write-Log "Configuration validation complete" -Level Info -Component "Config"

Write-Log "Starting script banner display..." -Level Info -Component "Init"
Write-Host "`n=== Image Processing Script Started ===" -ForegroundColor Cyan
Write-Host "Working Directory: $($Config.WorkingDirectory)" -ForegroundColor Cyan
Write-Host "Excluded Folders: $($Config.ExcludedFolders -join ', ')" -ForegroundColor Cyan
Write-Host "Supported Extensions: $($Config.SupportedExtensions -join ', ')" -ForegroundColor Cyan
Write-Host "API URL: $($Config.API.Url)" -ForegroundColor Cyan
Write-Host "API Timeout: $($Config.API.TimeoutSeconds) seconds" -ForegroundColor Cyan
Write-Host "Models:" -ForegroundColor Cyan
Write-Host "  - Image Analysis: $($Config.API.Models.ImageAnalysis)" -ForegroundColor Cyan
Write-Host "  - Text Generation: $($Config.API.Models.TextGeneration)" -ForegroundColor Cyan
Write-Host "===============================`n" -ForegroundColor Cyan

Write-Log "Configuration loaded. Working directory: $($Config.WorkingDirectory)" -Level Info

try {
    Write-Log "Loading required assemblies..." -Level Info -Component "Init"
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName WindowsBase
    Write-Log "Required assemblies loaded" -Level Info -Component "Init"
}
catch {
    Write-Log "Failed to load required assemblies: $($_.Exception.Message)" -Level Error -Component "Init"
    throw "Failed to load required assemblies: $($_.Exception.Message)"
}

function Test-IsImage {
    param (
        [string]$FilePath,
        [int]$FileIndex,
        [int]$TotalFiles
    )
    
    Write-Log "Starting Test-IsImage for $FilePath" -Level Info -Component "ImageValidation"
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    
    Write-Log "Validating image: $FilePath" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
    $img = $null
    try {
        $img = [System.Drawing.Image]::FromFile($FilePath)
        
        if ($img.Width -le 0 -or $img.Height -le 0) {
            throw "Invalid image dimensions"
        }
        
        if ($img.Size.IsEmpty) {
            throw "Empty image data"
        }
        
        $bitsPerPixel = switch ($img.PixelFormat) {
            ([System.Drawing.Imaging.PixelFormat]::Format1bppIndexed) { 1 }
            ([System.Drawing.Imaging.PixelFormat]::Format4bppIndexed) { 4 }
            ([System.Drawing.Imaging.PixelFormat]::Format8bppIndexed) { 8 }
            ([System.Drawing.Imaging.PixelFormat]::Format16bppGrayScale) { 16 }
            ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb) { 24 }
            ([System.Drawing.Imaging.PixelFormat]::Format32bppRgb) { 32 }
            ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb) { 32 }
            ([System.Drawing.Imaging.PixelFormat]::Format48bppRgb) { 48 }
            ([System.Drawing.Imaging.PixelFormat]::Format64bppArgb) { 64 }
            default { 0 }
        }
        
        if ($bitsPerPixel -eq 0) {
            throw "Unsupported pixel format"
        }
        
        Write-Log "Image validation successful" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "Image details:" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Dimensions: $($img.Width)x$($img.Height)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Pixel Format: $($img.PixelFormat) ($bitsPerPixel-bit)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Resolution: $($img.HorizontalResolution)x$($img.VerticalResolution) DPI" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Raw Format: $($img.RawFormat.Guid)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        
        $qualityScore = [math]::Min(100, [math]::Round(($img.Width * $img.Height * $bitsPerPixel) / 1000000))
        Write-Log "  - Quality Score: $qualityScore/100" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        
        return $true
    }
    catch [System.OutOfMemoryException] {
        Write-Log "File is too large to process: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    catch [System.IO.FileNotFoundException] {
        Write-Log "File not found: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    catch [System.UnauthorizedAccessException] {
        Write-Log "Access denied to file: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    catch {
        Write-Log "Invalid image file: $FilePath" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "Error details: $($_.Exception.Message)" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    finally {
        if ($img) {
            $img.Dispose()
        }
    }
}

Write-Log "Initializing circuit breaker state..." -Level Info -Component "CircuitBreaker"
$script:circuitBreakerState = @{
    Failures = 0
    LastFailure = $null
    IsOpen = $false
    CooldownMinutes = 5
}

function Reset-CircuitBreaker {
    Write-Log "Resetting circuit breaker" -Level Info -Component "CircuitBreaker"
    $script:circuitBreakerState.Failures = 0
    $script:circuitBreakerState.LastFailure = $null
    $script:circuitBreakerState.IsOpen = $false
    Write-Log "Circuit breaker reset complete" -Level Info -Component "CircuitBreaker"
}

function Test-CircuitBreaker {
    Write-Log "Testing circuit breaker state" -Level Info -Component "CircuitBreaker"
    if (-not $script:circuitBreakerState.IsOpen) {
        Write-Log "Circuit breaker is closed" -Level Info -Component "CircuitBreaker"
        return $true
    }
    
    if ((Get-Date) -gt $script:circuitBreakerState.LastFailure.AddMinutes($script:circuitBreakerState.CooldownMinutes)) {
        Write-Log "Circuit breaker cooldown period elapsed, resetting" -Level Info -Component "CircuitBreaker"
        Reset-CircuitBreaker
        return $true
    }
    
    Write-Log "Circuit breaker is open" -Level Info -Component "CircuitBreaker"
    return $false
}

function Invoke-LlamaAPI {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Model,
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        [PSCustomObject]$AdditionalData = $null,
        [int]$FileIndex,
        [int]$TotalFiles
    )

    Write-Log "Starting Invoke-LlamaAPI for model $Model" -Level Info -Component "API"

    if (-not (Test-CircuitBreaker)) {
        Write-Log "Circuit breaker is open. API calls temporarily disabled." -Level Error -Component "API"
        throw "Circuit breaker is open. API calls temporarily disabled."
    }

    Write-Log "Preparing API call for model: $Model" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
    
    try {
        $body = @{
            model = $Model
            format = "json"
            prompt = $Prompt
            stream = $false
            temperature = 0.7
            max_tokens = 500
            top_p = 0.9
        }

        if ($AdditionalData) {
            $body += $AdditionalData
            Write-Log "Additional data included in request" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
        }

        $bodyJson = $body | ConvertTo-Json -Depth 10 -Compress
        $payloadSize = [math]::Round($bodyJson.Length/1MB, 2)
        
        if ($payloadSize -gt $Config.API.MaxPayloadSizeMB) {
            throw "Payload size too large: ${payloadSize}MB (limit: $($Config.API.MaxPayloadSizeMB)MB)"
        }
        
        Write-Log "Request payload prepared (${payloadSize} MB)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"

        $lastError = $null
        for ($attempt = 1; $attempt -le $Config.API.MaxRetries; $attempt++) {
            try {
                Write-Log "API Call Attempt $attempt of $($Config.API.MaxRetries) for model $Model" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
                
                $startTime = Get-Date
                $response = Invoke-RestMethod `
                    -Uri $Config.API.Url `
                    -Method Post `
                    -Headers $Config.API.Headers `
                    -Body $bodyJson `
                    -TimeoutSec $Config.API.TimeoutSeconds
                $duration = ([math]::Round(((Get-Date) - $startTime).TotalSeconds, 2))
                Write-Log "Response received successfully ($duration seconds)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
                if (-not $response) {
                    throw "Empty response received"
                }
                
                if (-not $response.response) {
                    throw "Invalid API response format: Missing 'response' field"
                }

                Reset-CircuitBreaker
                
                try {
                    return $response.response | ConvertFrom-Json
                }
                catch {
                    throw "Failed to parse JSON response: $($_.Exception.Message)"
                }
            }
            catch [System.Net.WebException] {
                $lastError = $_
                $statusCode = [int]$_.Exception.Response.StatusCode
                Write-Log "HTTP Error $statusCode : $($_.Exception.Message)" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
                
                $script:circuitBreakerState.Failures++
                $script:circuitBreakerState.LastFailure = Get-Date
                
                if ($script:circuitBreakerState.Failures -ge 5) {
                    $script:circuitBreakerState.IsOpen = $true
                    throw "Circuit breaker opened due to multiple failures"
                }
                
                if ($statusCode -in @(400, 401, 403)) {
                    throw "Fatal API error: $($_.Exception.Message)"
                }
            }
            catch {
                $lastError = $_
                Write-Log "API call failed: $($_.Exception.Message)" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
            }

            if ($attempt -lt $Config.API.MaxRetries) {
                $waitTime = $Config.API.RetryDelaySeconds * [Math]::Pow(2, ($attempt - 1))
                Write-Log "Waiting $waitTime seconds before retry" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
                Start-Sleep -Seconds $waitTime
            }
        }
        
        throw "All API retry attempts failed. Last error: $($lastError.Exception.Message)"
    }
    catch {
        Write-Log "Fatal API error: $($_.Exception.Message)" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "API"
        throw
    }
}

function Get-ImageMetadata {
    param (
        [Parameter(Mandatory=$True)]
        [string]$Path
    )

    Write-Log "Starting Get-ImageMetadata for $Path" -Level Info -Component "Metadata"
    Write-Log "Processing file path: $Path" -Level Info -Component "Metadata"

    $FileItem = $null
    $FileStream = $null
    $Img = $null
    $metadata = @{}

    try {
        $FileItem = Resolve-Path $Path -ErrorAction Stop
        if (-not $FileItem) {
            throw "Failed to resolve path: $Path"
        }

        $ImageFile = (Get-ChildItem $FileItem.Path -ErrorAction Stop).FullName
        Write-Log "Resolved image file path: $ImageFile" -Level Info -Component "Metadata"

        $FileStream = New-Object System.IO.FileStream(
            $ImageFile, 
            [System.IO.FileMode]::Open, 
            [System.IO.FileAccess]::Read, 
            [System.IO.FileShare]::Read
        )
        
        $Img = [System.Drawing.Image]::FromStream($FileStream)
        
        foreach ($propId in $Img.PropertyIdList) {
            try {
                $prop = $Img.GetPropertyItem($propId)
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
                Write-Log "Found $($tag.Key): $($metadata[$tag.Value].Value)" -Level Info -Component "Metadata"
            }
        }

        return $metadata
    }
    catch {
        Write-Log "Failed to read metadata: $($_.Exception.Message)" -Level Warning -Component "Metadata"
        return $null
    }
    finally {
        if ($Img) { $Img.Dispose() }
        if ($FileStream) { 
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

    Write-Log "Starting Get-ExifDateTaken for $Path" -Level Info -Component "EXIF"
    Write-Log "Processing file path: $Path" -Level Info -Component "EXIF"

    $FileItem = Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ResolveError
    if ($ResolveError) {
        Write-Log "Bad path '$Path' ($($ResolveError[0].CategoryInfo.Category))" -Level Warning -Component "EXIF"
        return
    }

    $ImageFile = (Get-ChildItem $FileItem.Path).FullName
    Write-Log "Resolved image file path: $ImageFile" -Level Info -Component "EXIF"

    try {
        $FileStream = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $Img = [System.Drawing.Image]::FromStream($FileStream)
        $ExifDT = $Img.GetPropertyItem(36867)
    } catch {
        Write-Log "Failed to read EXIF data for file '$ImageFile'. Error: $_" -Level Warning -Component "EXIF"
        return
    } finally {
        if ($Img) { $Img.Dispose() }
        if ($FileStream) { $FileStream.Close() }
    }

    try {
        $ExifDtString = [System.Text.Encoding]::ASCII.GetString($ExifDT.Value).TrimEnd([char]0)
        $OldTime = [datetime]::ParseExact($ExifDtString, "yyyy:MM:dd HH:mm:ss", $null)
        Write-Log "Extracted DateTimeOriginal: $OldTime" -Level Info -Component "EXIF"
        return $OldTime
    } catch {
        Write-Log "Failed to parse EXIF DateTimeOriginal for file '$ImageFile'. Error: $_" -Level Warning -Component "EXIF"
        return
    }
}

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

        Write-Log "Generating new filename..." -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
        $newFilename = (Invoke-LlamaAPI `
            -Model $Config.API.Models.TextGeneration `
            -Prompt @"
Create a descriptive filename (max $($Config.Processing.FilenameMaxLength) chars) using:
Original name: '$($File.Name)'
Keywords: $($keywords -join ', ')
Metadata: $(if ($metadata) { "Available" } else { "Not available" })

Requirements:
1. Keep file extension: $($File.Extension)
2. Use underscores for spaces
3. Include most distinctive keyword
4. Add date if present in metadata/keywords
5. Maintain readability
6. Start with most important aspect
7. Include technical specs if relevant
8. Ensure uniqueness

Output JSON: {filename: string}
"@ `
            -FileIndex $FileIndex `
            -TotalFiles $TotalFiles).filename

        if (-not $newFilename) {
            throw "Failed to generate new filename"
        }

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
                    [System.IO.File]::SetCreationTime($paths.Renamed, $exifDate)
                    [System.IO.File]::SetLastWriteTime($paths.Renamed, $exifDate)
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

        Write-Log "Successfully processed: $($File.Name) → $newFilename" -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "Processing"
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

try {
    Write-Host "`n=== Starting Batch Processing ===" -ForegroundColor Cyan
    Write-Log "Starting file search in $($Config.WorkingDirectory)..." -Level Info -Component "BatchProcessing"
    
    if (-not (Test-Path $Config.WorkingDirectory)) {
        Write-Log "Working directory not found" -Level Error -Component "BatchProcessing"
        throw "Working directory not found: $($Config.WorkingDirectory)"
    }
    
    Write-Log "Searching for files..." -Level Info -Component "BatchProcessing"
    
    # Get all directories first to check for .skip files
    $allDirs = Get-ChildItem -Path $Config.WorkingDirectory -Directory -Recurse -ErrorAction Stop
    $skippedDirs = $allDirs | Where-Object { 
        Test-Path (Join-Path $_.FullName "*.skip")
    }
    
    Write-Log "Found $($skippedDirs.Count) directories with .skip files - these will be ignored" -Level Info -Component "BatchProcessing"
    
    # Get files excluding directories with .skip files
    $files = Get-ChildItem -Path $Config.WorkingDirectory -Recurse -File -ErrorAction Stop |
        Where-Object { 
            $Config.ExcludedFolders -notcontains $_.Directory.Name -and
            $Config.SupportedExtensions -contains $_.Extension.ToLower() -and
            -not ($skippedDirs | Where-Object { $_.FullName -eq $_.Directory.FullName -or 
                                               $_.FullName -eq (Split-Path $_.FullName) -or
                                               $_.FullName -contains $_.Directory.FullName })
        }

    $totalFiles = $files.Count
    if ($totalFiles -eq 0) {
        Write-Log "No files found matching criteria" -Level Warning -Component "BatchProcessing"
        return
    }

    Write-Log "Found $totalFiles files to process" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Supported extensions: $($Config.SupportedExtensions -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Excluded folders: $($Config.ExcludedFolders -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"

    Write-Log "Starting batch processing..." -Level Info -Component "BatchProcessing"
    $startTime = Get-Date
    $successCount = 0
    $failureCount = 0

    # Create index array, randomize if enabled in config
    $indices = 0..($files.Count - 1)
    if ($Config.Processing.RandomizeOrder) {
        Write-Log "Randomizing processing order..." -Level Info -Component "BatchProcessing"
        $indices = $indices | Get-Random -Count $files.Count
    }

    for ($i = 0; $i -lt $indices.Count; $i++) {
        $fileIndex = $indices[$i]
        try {
            Write-Log "Processing file $($i + 1) of $totalFiles" -Level Info -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
            Invoke-ImageProcessing -File $files[$fileIndex] -FileIndex ($i + 1) -TotalFiles $totalFiles
            $successCount++
            Write-Log "Successfully processed file $($i + 1)" -Level Info -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
        }
        catch {
            $failureCount++
            Write-Log "Failed to process file $($files[$fileIndex].Name): $($_.Exception.Message)" -Level Error -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
            Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
            continue
        }
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Failed ===" -ForegroundColor Red
}
finally {
    $duration = (Get-Date) - $startTime
    Write-Log "Processing complete. Total files processed: $totalFiles" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Successful: $successCount, Failed: $failureCount" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Total processing time: $([math]::Round($duration.TotalMinutes, 2)) minutes" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Complete ===" -ForegroundColor Cyan
}
