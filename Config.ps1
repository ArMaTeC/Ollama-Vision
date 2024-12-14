# Define the script directory path
# This is used to locate the Logging.ps1 script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Import the Logging.ps1 script
# This script is used for logging operations throughout the application
. (Join-Path $scriptDir 'Logging.ps1')

# Log the initialization of the Config
# This log entry is used for debugging and tracking purposes
Write-Log "Initializing circuit Config..." -Level Info -Component "Config"

# Define the configuration settings
# These settings are used throughout the application in scripts such as Metadata.ps1 and Config.ps1
# Usage examples:
# .\Run_BatchProcessing.ps1 -WorkingDirectory "C:\Images" -ExcludedFolders "renamed","original" -SupportedExtensions ".jpg",".jpeg",".png" -Url "http://localhost:11434/api/generate" -TimeoutSeconds 60 -MaxRetries 5 -RetryDelaySeconds 3 -MaxPayloadSizeMB 500 -ImageAnalysis "llama3.2-vision" -TextGeneration "gemma2" -LogLevel "Debug" -PreserveMetadata $true -FilenameMaxLength 100 -RandomizeOrder $true -MaxConcurrentFiles 8 -AddDatePrefix $true

param (
    [Parameter(Mandatory=$false)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory=$false)]
    [string[]]$ExcludedFolders,

    [Parameter(Mandatory=$false)]
    [string[]]$SupportedExtensions,

    [Parameter(Mandatory=$false)]
    [string]$Url,

    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds,

    [Parameter(Mandatory=$false)]
    [int]$MaxRetries,

    [Parameter(Mandatory=$false)]
    [int]$RetryDelaySeconds,

    [Parameter(Mandatory=$false)]
    [int]$MaxPayloadSizeMB,

    [Parameter(Mandatory=$false)]
    [string]$ImageAnalysis,

    [Parameter(Mandatory=$false)]
    [string]$TextGeneration,

    [Parameter(Mandatory=$false)]
    [string]$LogLevel,

    [Parameter(Mandatory=$false)]
    [bool]$PreserveMetadata,

    [Parameter(Mandatory=$false)]
    [int]$FilenameMaxLength,

    [Parameter(Mandatory=$false)]
    [bool]$RandomizeOrder,

    [Parameter(Mandatory=$false)]
    [int]$MaxConcurrentFiles,

    [Parameter(Mandatory=$false)]
    [bool]$AddDatePrefix
)

# Initialize default values
if (-not $WorkingDirectory) {
    $WorkingDirectory = (Get-Location)
}
if (-not $ExcludedFolders) {
    $ExcludedFolders = @("renamed", "original")
}
if (-not $SupportedExtensions) {
    $SupportedExtensions = @(".jpg", ".jpeg", ".png")
}
if (-not $Url) {
    $Url = "http://localhost:11434/api/generate"
}
if (-not $TimeoutSeconds) {
    $TimeoutSeconds = 60
}
if (-not $MaxRetries) {
    $MaxRetries = 5
}
if (-not $RetryDelaySeconds) {
    $RetryDelaySeconds = 3
}
if (-not $MaxPayloadSizeMB) {
    $MaxPayloadSizeMB = 500
}
if (-not $ImageAnalysis) {
    $ImageAnalysis = "llama3.2-vision"
}
if (-not $TextGeneration) {
    $TextGeneration = "gemma2"
}
if (-not $LogLevel) {
    $LogLevel = "Debug"
}
if (-not $PreserveMetadata) {
    $PreserveMetadata = $true
}
if (-not $FilenameMaxLength) {
    $FilenameMaxLength = 100
}
if (-not $RandomizeOrder) {
    $RandomizeOrder = $false
}
if (-not $MaxConcurrentFiles) {
    $MaxConcurrentFiles = [Math]::Min($env:NUMBER_OF_PROCESSORS, 8)
}
if (-not $AddDatePrefix) {
    $AddDatePrefix = $true
}
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