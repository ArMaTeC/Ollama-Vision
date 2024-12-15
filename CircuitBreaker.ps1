$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')

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