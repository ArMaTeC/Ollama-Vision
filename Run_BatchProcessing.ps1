# Ensure the script files are in the correct directory and update the paths if necessary
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Initialization.ps1')
. (Join-Path $scriptDir 'Logging.ps1')
. (Join-Path $scriptDir 'ImageProcessing.ps1')

try {
    Write-Host "`n=== Starting Batch Processing ===" -ForegroundColor Cyan
    Write-Log "Starting file search in $($Config.WorkingDirectory)..." -Level Info -Component "BatchProcessing"
    
    if (-not (Test-Path $Config.WorkingDirectory)) {
        Write-Log "Working directory not found" -Level Error -Component "BatchProcessing"
        throw "Working directory not found: $($Config.WorkingDirectory)"
    }
    
    Write-Log "Searching for files..." -Level Info -Component "BatchProcessing"
    
    $allDirs = Get-ChildItem -Path $Config.WorkingDirectory -Directory -Recurse -ErrorAction Stop
    $skippedDirs = $allDirs | Where-Object { 
        Test-Path (Join-Path $_.FullName "*.skip")
    }
    
    Write-Log "Found $($skippedDirs.Count) directories with .skip files - these will be ignored" -Level Info -Component "BatchProcessing"
    
    $files = Get-ChildItem -Path $Config.WorkingDirectory -Recurse -File -ErrorAction Stop |
        Where-Object { 
            $Config.ExcludedFolders -notcontains $_.Directory.Name -and
            $Config.SupportedExtensions -contains $_.Extension.ToLower() -and
            -not ($skippedDirs | Where-Object { $_.FullName -eq $_.Directory.FullName -or 
                                               $_.FullName -eq (Split-Path $_.FullName) -or
                                               $_.FullName -contains $_.Directory.FullName })
        }

    $totalFiles = $files.Count
    if ($totalFiles -eq 0) {
        Write-Log "No files found matching criteria" -Level Warning -Component "BatchProcessing"
        return
    }

    Write-Log "Found $totalFiles files to process" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Supported extensions: $($Config.SupportedExtensions -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Excluded folders: $($Config.ExcludedFolders -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"

    Write-Log "Starting batch processing..." -Level Info -Component "BatchProcessing"
    $startTime = Get-Date
    $successCount = 0
    $failureCount = 0

    $indices = 0..($files.Count - 1)
    if ($Config.Processing.RandomizeOrder) {
        Write-Log "Randomizing processing order..." -Level Info -Component "BatchProcessing"
        $indices = $indices | Get-Random -Count $files.Count
    }

    for ($i = 0; $i -lt $indices.Count; $i++) {
        $fileIndex = $indices[$i]
        try {
            Write-Log "Processing file $($i + 1) of $totalFiles" -Level Info -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
            Invoke-ImageProcessing -File $files[$fileIndex] -FileIndex ($i + 1) -TotalFiles $totalFiles
            $successCount++
            Write-Log "Successfully processed file $($i + 1)" -Level Info -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
        }
        catch {
            $failureCount++
            Write-Log "Failed to process file $($files[$fileIndex].Name): $($_.Exception.Message)" -Level Error -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
            Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex ($i + 1) -TotalFiles $totalFiles -Component "BatchProcessing"
            continue
        }
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Failed ===" -ForegroundColor Red
}
finally {
    $duration = (Get-Date) - $startTime
    Write-Log "Processing complete. Total files processed: $totalFiles" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Successful: $successCount, Failed: $failureCount" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Total processing time: $([math]::Round($duration.TotalMinutes, 2)) minutes" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Complete ===" -ForegroundColor Cyan
}