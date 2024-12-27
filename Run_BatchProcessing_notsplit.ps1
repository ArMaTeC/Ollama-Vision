if (-not (Get-Command Get-LogColor -ErrorAction SilentlyContinue)) {
    Write-Host "Logging.ps1 Get-LogColor function added" -ForegroundColor Green
    function Get-LogColor {
        param(
            [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
            [string]$Level
        )
        
        $colorMap = @{
            'Warning' = 'Yellow'
            'Error' = 'Red'
            'Debug' = 'DarkGray'
            'Info' = 'White'
        }
        
        return $colorMap[$Level]
    }
}

if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    Write-Host "Logging.ps1 write-log function added" -ForegroundColor Green
    function Write-Log {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Message,
            [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
            [string]$Level = 'Info',
            [int]$FileIndex = 0,
            [int]$TotalFiles = 0,
            [string]$Component = "Main",
            [switch]$NoConsole
        )
        
        # Check if the log level is enabled
        if ($Level -eq 'Debug' -and $Config.Logging.LogLevel -ne 'Debug') {
            return
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $prefix = if ($FileIndex -gt 0 -and $TotalFiles -gt 0) { "[$FileIndex/$TotalFiles]" } else { "" }
        $color = Get-LogColor -Level $Level
        $logMessage = "{0} {1} [{2}] [{3}] {4}" -f $timestamp, $prefix, $Level.ToUpper(), $Component, $Message
        
        # Output to console if NoConsole switch is not set
        if (-not $NoConsole) {
            Write-Host $logMessage -ForegroundColor $color
        }
        
        # Log to file if enabled in configuration
        if ($Config.Logging.LogToFile) {
            try {
                $logMessage | Out-File -Append -FilePath $Config.Logging.LogFile -ErrorAction Stop
            }
            catch {
                Write-Host "Failed to write log to file: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}


# Log the initialization of the Config
# This log entry is used for debugging and tracking purposes
Write-Log "Initializing circuit Config..." -Level Info -Component "Config"

# Define the configuration settings
# These settings are used throughout the application in scripts such as Metadata.ps1 and Config.ps1
# Usage examples:
# .\Run_BatchProcessing.ps1 -WorkingDirectory "C:\Images" -ExcludedFolders "renamed","original" -SupportedExtensions ".jpg",".jpeg",".png" -Url "http://localhost:11434/api/generate" -TimeoutSeconds 60 -MaxRetries 5 -RetryDelaySeconds 3 -MaxPayloadSizeMB 500 -ImageAnalysis "llama3.2-vision" -TextGeneration "gemma2" -LogLevel "Debug" -PreserveMetadata $true -FilenameMaxLength 100 -RandomizeOrder $true -MaxConcurrentFiles 8 -AddDatePrefix $true


# Initialize default values with parameter validation and clear defaults
$defaultValues = @{
    WorkingDirectory    = (Get-Location)
    ExcludedFolders    = @("renamed", "original") 
    SupportedExtensions = @(".jpg", ".jpeg", ".png")
    Url                = "http://localhost:11434/api/generate"
    TimeoutSeconds     = 60
    MaxRetries         = 5
    RetryDelaySeconds  = 3
    MaxPayloadSizeMB   = 500
    ImageAnalysis      = "llama3.2-vision"
    TextGeneration     = "gemma2"
    LogLevel           = "Debug"
    PreserveMetadata   = $true
    FilenameMaxLength  = 100
    RandomizeOrder     = $false
    MaxConcurrentFiles = [Math]::Min($env:NUMBER_OF_PROCESSORS, 8)
    AddDatePrefix      = $true
}



<# Example custom.ps1 file:
$defaultValues = @{
    WorkingDirectory    = "Z:\Photo"
    ExcludedFolders    = @("renamed", "original") 
    SupportedExtensions = @(".jpg", ".jpeg", ".png")
    Url                = "http://localhost:11434/api/generate"
    TimeoutSeconds     = 60
    MaxRetries         = 5
    RetryDelaySeconds  = 3
    MaxPayloadSizeMB   = 500
    ImageAnalysis      = "llama3.2-vision"
    TextGeneration     = "gemma2"
    LogLevel           = "Debug"
    PreserveMetadata   = $true
    FilenameMaxLength  = 100
    RandomizeOrder     = $true
    MaxConcurrentFiles = 8
    AddDatePrefix      = $true
}
#>

# Map arguments to variables, using defaults if not provided
$WorkingDirectory    = if ($args[0]) { $args[0] } else { $defaultValues.WorkingDirectory }
$ExcludedFolders    = if ($args[1]) { $args[1] } else { $defaultValues.ExcludedFolders }
$SupportedExtensions = if ($args[2]) { $args[2] } else { $defaultValues.SupportedExtensions }
$Url                = if ($args[3]) { $args[3] } else { $defaultValues.Url }
$TimeoutSeconds     = if ($args[4]) { $args[4] } else { $defaultValues.TimeoutSeconds }
$MaxRetries         = if ($args[5]) { $args[5] } else { $defaultValues.MaxRetries }
$RetryDelaySeconds  = if ($args[6]) { $args[6] } else { $defaultValues.RetryDelaySeconds }
$MaxPayloadSizeMB   = if ($args[7]) { $args[7] } else { $defaultValues.MaxPayloadSizeMB }
$ImageAnalysis      = if ($args[8]) { $args[8] } else { $defaultValues.ImageAnalysis }
$TextGeneration     = if ($args[9]) { $args[9] } else { $defaultValues.TextGeneration }
$LogLevel           = if ($args[10]) { $args[10] } else { $defaultValues.LogLevel }
$PreserveMetadata   = if ($args[11]) { $args[11] } else { $defaultValues.PreserveMetadata }
$FilenameMaxLength  = if ($args[12]) { $args[12] } else { $defaultValues.FilenameMaxLength }
$RandomizeOrder     = if ($args[13]) { $args[13] } else { $defaultValues.RandomizeOrder }
$MaxConcurrentFiles = if ($args[14]) { $args[14] } else { $defaultValues.MaxConcurrentFiles }
$AddDatePrefix      = if ($args[15]) { $args[15] } else { $defaultValues.AddDatePrefix }

$Config = @{

    # Define the working directory
    # This is used in Metadata.ps1 to determine the location of the files to process
    WorkingDirectory = $WorkingDirectory

    # Define the folders to exclude from processing
    # This is used in Metadata.ps1 to filter out certain directories
    ExcludedFolders = $ExcludedFolders

    # Define the supported file extensions
    # This is used in Metadata.ps1 to filter the files to process based on their extensions
    SupportedExtensions = $SupportedExtensions

    # Define the API settings
    # These settings are used in Metadata.ps1 for making API calls
    API = @{

        # Define the API URL
        Url = $Url

        # Define the API headers
        Headers = @{
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }

        # Define the API timeout in seconds
        TimeoutSeconds = $TimeoutSeconds

        # Define the maximum number of API retries
        MaxRetries = $MaxRetries

        # Define the delay between API retries in seconds
        RetryDelaySeconds = $RetryDelaySeconds

        # Define the maximum payload size for the API in MB
        MaxPayloadSizeMB = $MaxPayloadSizeMB

        # Define the models used by the API
        Models = @{
            ImageAnalysis = $ImageAnalysis
            TextGeneration = $TextGeneration
        }
    }

    # Define the logging settings
    # These settings are used in Logging.ps1 to control the level of logging
    Logging = @{

        # Define the log level
        LogLevel = $LogLevel
    }

    # Define the processing settings
    # These settings are used in Metadata.ps1 to control how the files are processed
    Processing = @{

        # Define whether to preserve metadata
        PreserveMetadata = $PreserveMetadata

        # Define the maximum length for filenames
        FilenameMaxLength = $FilenameMaxLength

        # Define whether to randomize the order of processing
        RandomizeOrder = $RandomizeOrder

        # Define the maximum number of concurrent files to process
        MaxConcurrentFiles = $MaxConcurrentFiles

        # Define whether to add a date prefix to filenames
        AddDatePrefix = $AddDatePrefix
    }
}
Write-Host "`n=== Current Configuration ===" -ForegroundColor Cyan
Write-Host ($Config | Format-List | Out-String)

# Log the loading of the Config
# This log entry is used for debugging and tracking purposes
Write-Log "Loaded Config..." -Level Info -Component "Config"

# Log the current configuration settings
# This log entry is used for debugging and tracking purposes
Write-Log "Current Configuration: $($Config | ConvertTo-Json -Depth 3)" -Level Info -Component "Config"


Write-Log "Script initialization starting..." -Level Info -Component "Init"

# Validate configuration
$validationErrors = @()
if (-not (Test-Path $Config.WorkingDirectory)) {
    $validationErrors += "Working directory does not exist: $($Config.WorkingDirectory)"
}
if (-not $Config.API.Url) {
    $validationErrors += "API URL is not configured"
}
if (-not $Config.API.Models.ImageAnalysis -or -not $Config.API.Models.TextGeneration) {
    $validationErrors += "Required API models are not configured"
}

if ($validationErrors.Count -gt 0) {
    foreach ($errors in $validationErrors) {
        Write-Log $errors -Level Error -Component "Config"
    }
    throw "Configuration validation failed with errors: $($validationErrors -join '; ')"
}

Write-Log "Configuration validation complete" -Level Info -Component "Config"

# Display script banner
$banner = @"
`n=== Image Processing Script Started ===
Working Directory: $($Config.WorkingDirectory)
Excluded Folders: $($Config.ExcludedFolders -join ', ')
Supported Extensions: $($Config.SupportedExtensions -join ', ')
API URL: $($Config.API.Url)
API Timeout: $($Config.API.TimeoutSeconds) seconds
Models:
  - Image Analysis: $($Config.API.Models.ImageAnalysis)
  - Text Generation: $($Config.API.Models.TextGeneration)
===============================`n
"@
Write-Host $banner -ForegroundColor Cyan

Write-Log "Configuration loaded. Working directory: $($Config.WorkingDirectory)" -Level Info

# Load required assemblies
try {
    Write-Log "Loading required assemblies..." -Level Info -Component "Init"
    Add-Type -AssemblyName System.Drawing, System.Web, WindowsBase
    Write-Log "Required assemblies loaded" -Level Info -Component "Init"
}
catch {
    $errorMessage = "Failed to load required assemblies: $($_.Exception.Message)"
    Write-Log $errorMessage -Level Error -Component "Init"
    throw $errorMessage
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
                #Write-Log "Attempting to get property item for property ID: $propId" -Level Debug -Component "Metadata"
                $prop = $Img.GetPropertyItem($propId)
                #Write-Log "Property item retrieved successfully for property ID: $propId" -Level Debug -Component "Metadata"
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
                #Write-Log "Metadata added for property ID: $propId" -Level Debug -Component "Metadata"
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
# Log the initialization of the circuit breaker state
Write-Log "Initializing circuit breaker state..." -Level Info -Component "CircuitBreaker"
# Initialize the circuit breaker state
$script:circuitBreakerState = @{
    Failures = 0
    LastFailure = $null
    IsOpen = $false
    CooldownMinutes = 5
    MaxFailures = 3
    LastReset = $null
}

# Function to reset the circuit breaker
function Reset-CircuitBreaker {
    # Log the reset action
    Write-Log "Resetting circuit breaker" -Level Info -Component "CircuitBreaker"
    # Reset the circuit breaker state
    $script:circuitBreakerState = @{
        Failures = 0
        LastFailure = $null
        IsOpen = $false
        CooldownMinutes = $script:circuitBreakerState.CooldownMinutes
        MaxFailures = $script:circuitBreakerState.MaxFailures
        LastReset = Get-Date
    }
    # Log the completion of the reset action
    Write-Log "Circuit breaker reset complete" -Level Info -Component "CircuitBreaker"
}

# Function to test the circuit breaker
function Test-CircuitBreaker {
    # Log the test action
    Write-Log "Testing circuit breaker state" -Level Info -Component "CircuitBreaker"
    # Check if the circuit breaker is open
    if (-not $script:circuitBreakerState.IsOpen) {
        # Log the state of the circuit breaker
        Write-Log "Circuit breaker is closed" -Level Info -Component "CircuitBreaker"
        return $true
    }
    
    # Calculate the end time of the cooldown period
    $cooldownEndTime = $script:circuitBreakerState.LastFailure.AddMinutes($script:circuitBreakerState.CooldownMinutes)
    # Check if the cooldown period has elapsed
    if ((Get-Date) -gt $cooldownEndTime) {
        # Log the reset action due to elapsed cooldown period
        Write-Log "Circuit breaker cooldown period elapsed, resetting" -Level Info -Component "CircuitBreaker"
        # Reset the circuit breaker
        Reset-CircuitBreaker
        return $true
    }
    
    # Log the state of the circuit breaker
    Write-Log "Circuit breaker is open" -Level Info -Component "CircuitBreaker"
    return $false
}

# Function to record a failure in the circuit breaker
function Add-CircuitBreakerFailure {
    # Log the failure recording action
    Write-Log "Recording failure" -Level Info -Component "CircuitBreaker"
    # Increment the failure count
    $script:circuitBreakerState.Failures++
    # Update the last failure time
    $script:circuitBreakerState.LastFailure = Get-Date
    # Check if the maximum failures have been reached
    if ($script:circuitBreakerState.Failures -ge $script:circuitBreakerState.MaxFailures) {
        # Log the opening of the circuit breaker due to max failures
        Write-Log "Max failures reached, opening circuit breaker" -Level Warning -Component "CircuitBreaker"
        # Open the circuit breaker
        $script:circuitBreakerState.IsOpen = $true
    }
}

# Function to get the status of the circuit breaker
function Get-CircuitBreakerStatus {
    # Log the status retrieval action
    Write-Log "Retrieving circuit breaker status" -Level Info -Component "CircuitBreaker"
    # Return the circuit breaker state
    return $script:circuitBreakerState
}

# Function to set the cooldown minutes of the circuit breaker
function Set-CircuitBreakerCooldownMinutes {
    param (
        [int]$Minutes
    )
    # Log the setting of the cooldown minutes
    Write-Log "Setting cooldown minutes to $Minutes" -Level Info -Component "CircuitBreaker"
    # Set the cooldown minutes
    $script:circuitBreakerState.CooldownMinutes = $Minutes
}

# Function to set the maximum failures of the circuit breaker
function Set-CircuitBreakerMaxFailures {
    param (
        [int]$MaxFailures
    )
    # Log the setting of the maximum failures
    Write-Log "Setting max failures to $MaxFailures" -Level Info -Component "CircuitBreaker"
    # Set the maximum failures
    $script:circuitBreakerState.MaxFailures = $MaxFailures
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
            keep_alive = -1
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


function Test-FileLock {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('FullName','PSPath')]
        [string[]]$FilePath,
        [int]$FileIndex = 0,
        [int]$TotalFiles = 0
    )

    Process {
        ForEach ($Item in $FilePath) {
            $Item = Convert-Path $Item
            $result = @{
                File = $Item 
                IsLocked = $false
                Reason = ""
            }

            If (-not [System.IO.File]::Exists($Item)) {
                $result.IsLocked = $true
                $result.Reason = "File does not exist"
                [pscustomobject]$result
                continue
            }

            try {
                $FileStream = [System.IO.File]::Open($Item, 'Open', 'Write', 'None')
                $FileStream.Close()
                $FileStream.Dispose()
                
                $imageViewerProcesses = @(
                    'Microsoft.Photos', 'PhotoViewer', 'ImageGlass', 'IrfanView',
                    'Windows Photo Viewer', 'PhotosApp', 'dllhost',
                    'Photoshop', 'LightRoom', 'Paint', 'mspaint',
                    'ACDSee', 'FastStone', 'XnView', 'nomacs'
                )
                
                $fileName = Split-Path $Item -Leaf
                $dirName = Split-Path (Split-Path $Item -Parent) -Leaf
                
                $processes = Get-Process | Where-Object { 
                    $imageViewerProcesses -contains $_.ProcessName -and (
                        $_.MainWindowTitle -match [regex]::Escape($fileName) -or
                        $_.Path -eq $Item -or
                        $_.MainWindowTitle -match [regex]::Escape($dirName)
                    )
                }
                
                if ($processes.Count -gt 0) {
                    $result.IsLocked = $true
                    $result.Reason = "File open in: $($processes[0].ProcessName)"
                }
            }
            catch [System.UnauthorizedAccessException] {
                $result.IsLocked = $true
                $result.Reason = "Access Denied: $($_.Exception.Message)"
            }
            catch {
                $result.IsLocked = $true
                $result.Reason = "Unknown error: $($_.Exception.Message)" 
            }
            finally {
                if ($FileStream) {
                    $FileStream.Dispose()
                }
            }

            [pscustomobject]$result
        }
    }
}

try {
    Write-Host "`n=== Starting Batch Processing ===" -ForegroundColor Cyan
    Write-Log "Starting file search in $($Config.WorkingDirectory)..." -Level Info -Component "BatchProcessing"
    
    $progressParams = @{
        Activity = "Batch Processing"
        Status = "Initializing..."
        PercentComplete = 0
    }
    Write-Progress @progressParams
    
    if (-not (Test-Path $Config.WorkingDirectory -PathType Container)) {
        throw "Working directory not found or not accessible: $($Config.WorkingDirectory)"
    }
    
    Write-Log "Searching for files..." -Level Info -Component "BatchProcessing"
    
    # Find directories with .skip files
    $skippedDirs = Get-ChildItem -Path $Config.WorkingDirectory -Directory -Recurse -ErrorAction Stop | 
        Where-Object { Test-Path (Join-Path $_.FullName "*.skip") -ErrorAction SilentlyContinue }
    
    Write-Log "Found $($skippedDirs.Count) directories with .skip files - these will be ignored" -Level Info -Component "BatchProcessing"
    
    $maxFileSizeMB = 100
    
    # Get eligible files using more efficient filtering
    $files = Get-ChildItem -Path $Config.WorkingDirectory -Recurse -File -ErrorAction Stop |
        Where-Object { 
            if ($_.Length -ge ($maxFileSizeMB * 1MB)) {
                Write-Log "Skipping oversized file $($_.FullName)" -Level Warning -Component "BatchProcessing"
                return $false
            }
            
            $Config.SupportedExtensions -contains $_.Extension.ToLower() -and
            $Config.ExcludedFolders -notcontains $_.Directory.Name -and
            -not ($skippedDirs | Where-Object { $_.FullName -eq $_.Directory.FullName -or $_.FullName -eq (Split-Path $_.FullName) })
        }

    $totalFiles = $files.Count
    if ($totalFiles -eq 0) {
        Write-Log "No files found matching criteria" -Level Warning -Component "BatchProcessing"
        return
    }

    $initialMemory = [System.GC]::GetTotalMemory($true)
    
    Write-Log "Found $totalFiles files to process" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Supported extensions: $($Config.SupportedExtensions -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Excluded folders: $($Config.ExcludedFolders -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Maximum file size: ${maxFileSizeMB}MB" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"

    Write-Log "Starting batch processing..." -Level Info -Component "BatchProcessing"
    $startTime = Get-Date
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0
    $failedFiles = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Process files in parallel if configured
    $indices = if ($Config.Processing.RandomizeOrder) {
        Write-Log "Randomizing processing order..." -Level Info -Component "BatchProcessing"
        0..($files.Count - 1) | Get-Random -Count $files.Count
    } else {
        0..($files.Count - 1)
    }

    $batchSize = [Math]::Min(10, [int]($totalFiles * 0.1)) # Adjust batch size based on total files
    $currentBatch = 0

    foreach ($i in $indices) {
        $currentFile = $files[$i]
        $currentFileNumber = $i + 1
        
        if ($currentFileNumber % 10 -eq 0) {
            $progressParams.Status = "Processing file $currentFileNumber of $totalFiles"
            $progressParams.PercentComplete = ($currentFileNumber / $totalFiles * 100)
            Write-Progress @progressParams
        }
        
        try {
            Write-Log "Processing file $currentFileNumber of $totalFiles" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            
            $lockStatus = Test-FileLock -FilePath $currentFile.FullName -FileIndex $currentFileNumber -TotalFiles $totalFiles
            
            if ($lockStatus.IsLocked) {
                Write-Log "File is locked, skipping: $($currentFile.Name). Reason: $($lockStatus.Reason)" -Level Warning -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
                $skippedCount++
                continue
            }

            Write-Log "File is not locked, $($currentFile.Name)" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            Invoke-ImageProcessing -File $currentFile -FileIndex $currentFileNumber -TotalFiles $totalFiles
            $successCount++
            Write-Log "Successfully processed file $currentFileNumber" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
        }
        catch {
            $failureCount++
            $failedFiles.Add([PSCustomObject]@{
                Path = $currentFile.FullName
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            })
            Write-Log "Failed to process file $($currentFile.Name): $($_.Exception.Message)" -Level Error -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            continue
        }
        
        $currentBatch++
        if ($currentBatch -ge $batchSize) {
            [System.GC]::Collect()
            $currentBatch = 0
            Start-Sleep -Milliseconds 100 # Brief pause to allow system resources to stabilize
        }
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Failed ===" -ForegroundColor Red
}
finally {
    Write-Progress -Activity "Batch Processing" -Completed
    
    $duration = (Get-Date) - $startTime
    $memoryUsed = ([System.GC]::GetTotalMemory($true) - $initialMemory) / 1MB
    
    Write-Log "Processing complete. Total files processed: $totalFiles" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Successful: $successCount, Failed: $failureCount, Skipped: $skippedCount" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Memory used: $([math]::Round($memoryUsed, 2))MB" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    
    if ($failedFiles.Count -gt 0) {
        Write-Log "Failed files:" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
        foreach ($failedFile in $failedFiles) {
            Write-Log "  File: $($failedFile.Path)" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
            Write-Log "  Error: $($failedFile.Error)" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
        }
    }
    
    Write-Log "Total processing time: $([math]::Round($duration.TotalMinutes, 2)) minutes" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Complete ===" -ForegroundColor Cyan
}