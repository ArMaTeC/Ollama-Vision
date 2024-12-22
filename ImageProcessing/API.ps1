$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir '..\Logging\Logging.ps1')
. (Join-Path $scriptDir 'CircuitBreaker.ps1')

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