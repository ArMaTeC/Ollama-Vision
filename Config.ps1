
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
$Config = @{

    # Define the working directory
    # This is used in Metadata.ps1 to determine the location of the files to process
    WorkingDirectory = Get-Location

    # Define the folders to exclude from processing
    # This is used in Metadata.ps1 to filter out certain directories
    ExcludedFolders = @("renamed", "original")

    # Define the supported file extensions
    # This is used in Metadata.ps1 to filter the files to process based on their extensions
    SupportedExtensions = @(".jpg", ".jpeg", ".png")

    # Define the API settings
    # These settings are used in Metadata.ps1 for making API calls
    API = @{

        # Define the API URL
        Url = "http://localhost:11434/api/generate"

        # Define the API headers
        Headers = @{
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }

        # Define the API timeout in seconds
        TimeoutSeconds = 60

        # Define the maximum number of API retries
        MaxRetries = 5

        # Define the delay between API retries in seconds
        RetryDelaySeconds = 3

        # Define the maximum payload size for the API in MB
        MaxPayloadSizeMB = 500

        # Define the models used by the API
        Models = @{
            ImageAnalysis = "llama3.2-vision"
            TextGeneration = "gemma2"
        }
    }

    # Define the logging settings
    # These settings are used in Logging.ps1 to control the level of logging
    Logging = @{

        # Define the log level
        LogLevel = "Debug"
    }

    # Define the processing settings
    # These settings are used in Metadata.ps1 to control how the files are processed
    Processing = @{

        # Define whether to preserve metadata
        PreserveMetadata = $true

        # Define the maximum length for filenames
        FilenameMaxLength = 100

        # Define whether to randomize the order of processing
        RandomizeOrder = $true

        # Define the maximum number of concurrent files to process
        MaxConcurrentFiles = [Math]::Min($env:NUMBER_OF_PROCESSORS, 8)

        # Define whether to add a date prefix to filenames
        AddDatePrefix = $true
    }
}

# Log the loading of the Config
# This log entry is used for debugging and tracking purposes
Write-Log "Loaded Config..." -Level Info -Component "Config"

# Log the current configuration settings
# This log entry is used for debugging and tracking purposes
Write-Log "Current Configuration: $($Config | ConvertTo-Json -Depth 3)" -Level Info -Component "Config"