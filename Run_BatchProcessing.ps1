$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Initialization.ps1')
. (Join-Path $scriptDir 'Logging.ps1')
. (Join-Path $scriptDir 'ImageProcessing.ps1')

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
            # Ensure this is a full path
            $Item = Convert-Path $Item

            $result = @{
                File = $Item 
                IsLocked = $false
                Reason = ""
            }

            # Verify that this is a file and not a directory
            If ([System.IO.File]::Exists($Item)) {
                try {
                    # Method 1: Try to open file with exclusive write access
                    $FileStream = [System.IO.File]::Open($Item, 'Open', 'Write', 'None')
                    $FileStream.Close()
                    $FileStream.Dispose()
                    
                    # Method 2: Check for common image viewer and editor processes
                    $imageViewerProcesses = @(
                        'Microsoft.Photos', 'PhotoViewer', 'ImageGlass', 'IrfanView',
                        'Windows Photo Viewer', 'PhotosApp', 'dllhost',
                        'Photoshop', 'LightRoom', 'Paint', 'mspaint',
                        'ACDSee', 'FastStone', 'XnView', 'nomacs',
                        'Explorer'
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
                        [pscustomobject]$result
                        continue
                    }

                    # If we get here, file is not locked
                    $result.IsLocked = $false
                    $result.Reason = ""
                }
                catch [System.UnauthorizedAccessException] {
                    $result.IsLocked = "AccessDenied"
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
            }
            else {
                $result.IsLocked = $true
                $result.Reason = "File does not exist"
            }

            [pscustomobject]$result
        }
    }
}

try {


    Write-Host "`n=== Starting Batch Processing ===" -ForegroundColor Cyan
    Write-Log "Starting file search in $($Config.WorkingDirectory)..." -Level Info -Component "BatchProcessing"
    
    # Add progress bar
    $progressParams = @{
        Activity = "Batch Processing"
        Status = "Initializing..."
        PercentComplete = 0
    }
    Write-Progress @progressParams
    
    # Validate working directory exists and is accessible
    if (-not (Test-Path $Config.WorkingDirectory -PathType Container)) {
        Write-Log "Working directory not found or not accessible" -Level Error -Component "BatchProcessing"
        throw "Working directory not found or not accessible: $($Config.WorkingDirectory)"
    }
    
    Write-Log "Searching for files..." -Level Info -Component "BatchProcessing"
    
    # Get directories to skip (containing .skip files) with improved error handling
    $allDirs = Get-ChildItem -Path $Config.WorkingDirectory -Directory -Recurse -ErrorAction Stop
    $skippedDirs = $allDirs | Where-Object { 
        try {
            Test-Path (Join-Path $_.FullName "*.skip") -ErrorAction Stop
        }
        catch {
            Write-Log "Error checking skip file in directory $($_.FullName): $($_.Exception.Message)" -Level Warning -Component "BatchProcessing"
            $false
        }
    }
    
    Write-Log "Found $($skippedDirs.Count) directories with .skip files - these will be ignored" -Level Info -Component "BatchProcessing"
    
    # Add file size validation
    $maxFileSizeMB = 100
    
    # Get files to process with improved filtering
    $files = Get-ChildItem -Path $Config.WorkingDirectory -Recurse -File -ErrorAction Stop |
        Where-Object { 
            $isValidSize = $_.Length -lt ($maxFileSizeMB * 1MB)
            $isValidExtension = $Config.SupportedExtensions -contains $_.Extension.ToLower()
            $isNotExcluded = $Config.ExcludedFolders -notcontains $_.Directory.Name
            $isNotInSkippedDir = -not ($skippedDirs | Where-Object { 
                $_.FullName -eq $_.Directory.FullName -or 
                $_.FullName -eq (Split-Path $_.FullName) -or
                $_.FullName -contains $_.Directory.FullName 
            })
            
            if (-not $isValidSize) {
                Write-Log "Skipping oversized file $($_.FullName)" -Level Warning -Component "BatchProcessing"
            }
            
            $isValidSize -and $isValidExtension -and $isNotExcluded -and $isNotInSkippedDir
        }

    $totalFiles = $files.Count
    if ($totalFiles -eq 0) {
        Write-Log "No files found matching criteria" -Level Warning -Component "BatchProcessing"
        return
    }

    # Add memory usage monitoring
    $initialMemory = [System.GC]::GetTotalMemory($true)
    
    # Log initial processing information
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

    # Create and optionally randomize processing order
    $indices = 0..($files.Count - 1)
    if ($Config.Processing.RandomizeOrder) {
        Write-Log "Randomizing processing order..." -Level Info -Component "BatchProcessing"
        $indices = $indices | Get-Random -Count $files.Count
    }

    # Add batch size control
    $batchSize = 10
    $currentBatch = 0

    # Process each file with improved progress tracking
    foreach ($i in 0..($indices.Count - 1)) {
        $fileIndex = $indices[$i]
        $currentFile = $files[$fileIndex]
        $currentFileNumber = $i + 1
        
        # Update progress bar
        $progressParams.Status = "Processing file $currentFileNumber of $totalFiles"
        $progressParams.PercentComplete = ($currentFileNumber / $totalFiles * 100)
        Write-Progress @progressParams
        
        try {
            Write-Log "Processing file $currentFileNumber of $totalFiles" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            
            # Check if file is locked
            $lockStatus = Test-FileLock -FilePath $currentFile.FullName -FileIndex $currentFileNumber -TotalFiles $totalFiles
            
            if ($lockStatus.IsLocked) {
                Write-Log "File is locked, skipping: $($currentFile.Name). Reason: $($lockStatus.Reason)" -Level Warning -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
                $skippedCount++
                continue
            }
            else {
                Write-Log "File is not locked, $($currentFile.Name)" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
                Invoke-ImageProcessing -File $currentFile -FileIndex $currentFileNumber -TotalFiles $totalFiles
                $successCount++
                Write-Log "Successfully processed file $currentFileNumber" -Level Info -FileIndex $currentFileNumber -TotalFiles $totalFiles -Component "BatchProcessing"
            }
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
        
        # Batch memory management
        $currentBatch++
        if ($currentBatch -ge $batchSize) {
            [System.GC]::Collect()
            $currentBatch = 0
        }
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error -FileIndex 0 -TotalFiles $totalFiles -Component "BatchProcessing"
    Write-Host "`n=== Batch Processing Failed ===" -ForegroundColor Red
}
finally {
    # Clean up progress bar
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