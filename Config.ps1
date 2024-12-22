$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging\Logging.ps1')

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

# Check if custom config exists and load it
$customConfigPath = Join-Path $scriptDir 'custom_config.ps1'
if (Test-Path $customConfigPath) {
    . $customConfigPath
    Write-Log "Loaded custom configuration from $customConfigPath" -Level Info -Component "Config"
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