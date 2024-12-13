$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')

Write-Log "Initializing circuit Config..." -Level Info -Component "Config"
$Config = @{
    WorkingDirectory = Get-Location
    ExcludedFolders = @("renamed", "original")
    SupportedExtensions = @(".jpg", ".jpeg", ".png")
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
        LogLevel = "Debug"
    }
    Processing = @{
        PreserveMetadata = $true
        FilenameMaxLength = 100
        RandomizeOrder = $false
        MaxConcurrentFiles = [Math]::Min($env:NUMBER_OF_PROCESSORS, 8)
        AddDatePrefix = $true
    }
}
Write-Log "Loaded Config..." -Level Info -Component "Config"
Write-Log "Current Configuration: $($Config | ConvertTo-Json -Depth 3)" -Level Info -Component "Config"