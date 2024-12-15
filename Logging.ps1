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
