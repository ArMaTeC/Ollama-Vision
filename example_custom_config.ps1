$defaultValues = @{
    WorkingDirectory    = "D:\Images"
    ExcludedFolders    = @("temp", "backup") 
    SupportedExtensions = @(".jpg", ".jpeg", ".png", ".gif")
    Url                = "http://api.example.com/generate"
    TimeoutSeconds     = 120
    MaxRetries         = 3
    RetryDelaySeconds  = 5
    MaxPayloadSizeMB   = 1000
    ImageAnalysis      = "custom-model"
    TextGeneration     = "custom-llm"
    LogLevel           = "Info"
    PreserveMetadata   = $false
    FilenameMaxLength  = 150
    RandomizeOrder     = $true
    MaxConcurrentFiles = 4
    AddDatePrefix      = $false
}