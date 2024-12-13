$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')

Write-Log "Initializing circuit breaker state..." -Level Info -Component "CircuitBreaker"
$script:circuitBreakerState = @{
    Failures = 0
    LastFailure = $null
    IsOpen = $false
    CooldownMinutes = 5
    MaxFailures = 3
    LastReset = $null
}

function Reset-CircuitBreaker {
    Write-Log "Resetting circuit breaker" -Level Info -Component "CircuitBreaker"
    $script:circuitBreakerState = @{
        Failures = 0
        LastFailure = $null
        IsOpen = $false
        CooldownMinutes = $script:circuitBreakerState.CooldownMinutes
        MaxFailures = $script:circuitBreakerState.MaxFailures
        LastReset = Get-Date
    }
    Write-Log "Circuit breaker reset complete" -Level Info -Component "CircuitBreaker"
}

function Test-CircuitBreaker {
    Write-Log "Testing circuit breaker state" -Level Info -Component "CircuitBreaker"
    if (-not $script:circuitBreakerState.IsOpen) {
        Write-Log "Circuit breaker is closed" -Level Info -Component "CircuitBreaker"
        return $true
    }
    
    $cooldownEndTime = $script:circuitBreakerState.LastFailure.AddMinutes($script:circuitBreakerState.CooldownMinutes)
    if ((Get-Date) -gt $cooldownEndTime) {
        Write-Log "Circuit breaker cooldown period elapsed, resetting" -Level Info -Component "CircuitBreaker"
        Reset-CircuitBreaker
        return $true
    }
    
    Write-Log "Circuit breaker is open" -Level Info -Component "CircuitBreaker"
    return $false
}

function Add-CircuitBreakerFailure {
    Write-Log "Recording failure" -Level Info -Component "CircuitBreaker"
    $script:circuitBreakerState.Failures++
    $script:circuitBreakerState.LastFailure = Get-Date
    if ($script:circuitBreakerState.Failures -ge $script:circuitBreakerState.MaxFailures) {
        Write-Log "Max failures reached, opening circuit breaker" -Level Warning -Component "CircuitBreaker"
        $script:circuitBreakerState.IsOpen = $true
    }
}

function Get-CircuitBreakerStatus {
    Write-Log "Retrieving circuit breaker status" -Level Info -Component "CircuitBreaker"
    return $script:circuitBreakerState
}

function Set-CircuitBreakerCooldownMinutes {
    param (
        [int]$Minutes
    )
    Write-Log "Setting cooldown minutes to $Minutes" -Level Info -Component "CircuitBreaker"
    $script:circuitBreakerState.CooldownMinutes = $Minutes
}

function Set-CircuitBreakerMaxFailures {
    param (
        [int]$MaxFailures
    )
    Write-Log "Setting max failures to $MaxFailures" -Level Info -Component "CircuitBreaker"
    $script:circuitBreakerState.MaxFailures = $MaxFailures
}