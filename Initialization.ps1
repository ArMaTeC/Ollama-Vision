$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')
. (Join-Path $scriptDir 'Config.ps1')

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
    foreach ($error in $validationErrors) {
        Write-Log $error -Level Error -Component "Config"
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