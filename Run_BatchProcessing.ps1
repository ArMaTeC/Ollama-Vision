$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Initialization/Initialization.ps1')
. (Join-Path $scriptDir 'Logging/Logging.ps1')
. (Join-Path $scriptDir 'ImageProcessing/ImageProcessing.ps1')

function Test-FileLock {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('FullName','PSPath')]
        [string[]]$FilePath,
        [int]$FileIndex = 0,
        [int]$TotalFiles = 0
    )

    Process {
        ForEach ($Item in $FilePath) {
            $Item = Convert-Path $Item
            $result = @{
                File = $Item 
                IsLocked = $false
                Reason = ""
            }

            If (-not [System.IO.File]::Exists($Item)) {
                $result.IsLocked = $true
                $result.Reason = "File does not exist"
                [pscustomobject]$result
                continue
            }

            try {
                $FileStream = [System.IO.File]::Open($Item, 'Open', 'Write', 'None')
                $FileStream.Close()
                $FileStream.Dispose()
                
                $imageViewerProcesses = @(
                    'Microsoft.Photos', 'PhotoViewer', 'ImageGlass', 'IrfanView',
                    'Windows Photo Viewer', 'PhotosApp', 'dllhost',
                    'Photoshop', 'LightRoom', 'Paint', 'mspaint',
                    'ACDSee', 'FastStone', 'XnView', 'nomacs'
                )
                
                $fileName = Split-Path $Item -Leaf
                $dirName = Split-Path (Split-Path $Item -Parent) -Leaf
                
                $processes = Get-Process | Where-Object { 
                    $imageViewerProcesses -contains $_.ProcessName -and (
                        $_.MainWindowTitle -match [regex]::Escape($fileName) -or
                        $_.Path -eq $Item -or
                        $_.MainWindowTitle -match [regex]::Escape($dirName)
                    )
                }
                
                if ($processes.Count -gt 0) {
                    $result.IsLocked = $true
                    $result.Reason = "File open in: $($processes[0].ProcessName)"
                }
            }
            catch [System.UnauthorizedAccessException] {
                $result.IsLocked = $true
                $result.Reason = "Access Denied: $($_.Exception.Message)"
            }
            catch {
                $result.IsLocked = $true
                $result.Reason = "Unknown error: $($_.Exception.Message)" 
            }
            finally {
                if ($FileStream) {
                    $FileStream.Dispose()
                }
            }

            [pscustomobject]$result
        }
    }
}

try {
    Write-Host "`n=== Starting Batch Processing ===" -ForegroundColor Cyan
    Write-Log "Starting file search in $($Config.WorkingDirectory)..." -Level Info -Component "BatchProcessing"
    
    $progressParams = @{
        Activity = "Batch Processing"
        Status = "Initializing..."
        PercentComplete = 0
    }
    Write-Progress @progressParams
    
    if (-not (Test-Path $Config.WorkingDirectory -PathType Container)) {
        throw "Working directory not found or not accessible: $($Config.WorkingDirectory)"
    }
    
    Write-Log "Searching for files..." -Level Info -Component "BatchProcessing"
    
    # Find directories with .skip files
    $skippedDirs = Get-ChildItem -Path $Config.WorkingDirectory -Directory -Recurse -ErrorAction Stop | 
        Where-Object { Test-Path (Join-Path $_.FullName "*.skip") -ErrorAction SilentlyContinue }
    
    Write-Log "Found $($skippedDirs.Count) directories with .skip files - these will be ignored" -Level Info -Component "BatchProcessing"
    
    $maxFileSizeMB = 100
    
    # Get eligible files using more efficient filtering
    $files = Get-ChildItem -Path $Config.WorkingDirectory -Recurse -File -ErrorAction Stop |
        Where-Object { 
            if ($_.Length -ge ($maxFileSizeMB * 1MB)) {
                Write-Log "Skipping oversized file $($_.FullName)" -Level Warning -Component "BatchProcessing"
                return $false
            }
            
            $Config.SupportedExtensions -contains $_.Extension.ToLower() -and
            $Config.ExcludedFolders -notcontains $_.Directory.Name -and
            -not ($skippedDirs | Where-Object { $_.FullName -eq $_.Directory.FullName -or $_.FullName -eq (Split-Path $_.FullName) })
        }

    $totalFiles = $files.Count
    if ($totalFiles -eq 0) {
        Write-Log "No files found matching criteria" -Level Warning -Component "BatchProcessing"
        return
    }

    $initialMemory = [System.GC]::GetTotalMemory($true)
    
    Write-Log "Found $totalFiles files to process" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Supported extensions: $($Config.SupportedExtensions -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Excluded folders: $($Config.ExcludedFolders -join ', ')" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Maximum file size: ${maxFileSizeMB}MB" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"

    Write-Log "Starting batch processing..." -Level Info -Component "BatchProcessing"
    $startTime = Get-Date
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0
    $failedFiles = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Process files in parallel if configured
    $indices = if ($Config.Processing.RandomizeOrder) {
        Write-Log "Randomizing processing order..." -Level Info -Component "BatchProcessing"
        0..($files.Count - 1) | Get-Random -Count $files.Count
    } else {
        0..($files.Count - 1)
    }

    $batchSize = [Math]::Min(10, [int]($totalFiles * 0.1)) # Adjust batch size based on total files
    $currentBatch = 0

    foreach ($i in $indices) {
        $currentFile = $files[$i]
        $currentFileNumber = $i + 1
        
        if ($currentFileNumber % 10 -eq 0) {
            $progressParams.Status = "Processing file $currentFileNumber of $totalFiles"
            $progressParams.PercentComplete = ($currentFileNumber / $totalFiles * 100)
            Write-Progress @progressParams
        }
        
        try {
            Write-Log "Processing file $currentFileNumber of $totalFiles" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            
            $lockStatus = Test-FileLock -FilePath $currentFile.FullName -FileIndex $currentFileNumber -TotalFiles $totalFiles
            
            if ($lockStatus.IsLocked) {
                Write-Log "File is locked, skipping: $($currentFile.Name). Reason: $($lockStatus.Reason)" -Level Warning -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
                $skippedCount++
                continue
            }

            Write-Log "File is not locked, $($currentFile.Name)" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            Invoke-ImageProcessing -File $currentFile -FileIndex $currentFileNumber -TotalFiles $totalFiles
            $successCount++
            Write-Log "Successfully processed file $currentFileNumber" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
        }
        catch {
            $failureCount++
            $failedFiles.Add([PSCustomObject]@{
                Path = $currentFile.FullName
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            })
            Write-Log "Failed to process file $($currentFile.Name): $($_.Exception.Message)" -Level Error -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            continue
        }
        
        $currentBatch++
        if ($currentBatch -ge $batchSize) {
            [System.GC]::Collect()
            $currentBatch = 0
            Start-Sleep -Milliseconds 100 # Brief pause to allow system resources to stabilize
        }
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Failed ===" -ForegroundColor Red
}
finally {
    Write-Progress -Activity "Batch Processing" -Completed
    
    $duration = (Get-Date) - $startTime
    $memoryUsed = ([System.GC]::GetTotalMemory($true) - $initialMemory) / 1MB
    
    Write-Log "Processing complete. Total files processed: $totalFiles" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Successful: $successCount, Failed: $failureCount, Skipped: $skippedCount" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Memory used: $([math]::Round($memoryUsed, 2))MB" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    
    if ($failedFiles.Count -gt 0) {
        Write-Log "Failed files:" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
        foreach ($failedFile in $failedFiles) {
            Write-Log "  File: $($failedFile.Path)" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
            Write-Log "  Error: $($failedFile.Error)" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
        }
    }
    
    Write-Log "Total processing time: $([math]::Round($duration.TotalMinutes, 2)) minutes" -Level Info -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Complete ===" -ForegroundColor Cyan
}