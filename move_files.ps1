# PowerShell script to move files from 'renamed' folders up one level
$sourcePath = Get-Location

# Get all folders named 'renamed' recursively
$renamedFolders = Get-ChildItem -Path $sourcePath -Directory -Recurse | Where-Object { $_.Name -eq "renamed" }
$orignalFolders = Get-ChildItem -Path $sourcePath -Directory -Recurse | Where-Object { $_.Name -eq "original" }
foreach ($folder in $renamedFolders) {
    # Get all files in the current 'renamed' folder
    $files = Get-ChildItem -Path $folder.FullName -File
    
    foreach ($file in $files) {
        # Get the parent directory of the 'renamed' folder
        $destinationPath = Split-Path -Parent $folder.FullName
        $destinationFile = Join-Path -Path $destinationPath -ChildPath $file.Name
        
        # Move the file up one level
        try {
            Move-Item -Path $file.FullName -Destination $destinationFile -Force
            Write-Host "Moved $($file.Name) to $destinationPath"
        }
        catch {
            Write-Host "Error moving $($file.Name): $_" -ForegroundColor Red
        }
    }
    
    # Optional: Remove empty 'renamed' folder after moving files
    if ((Get-ChildItem -Path $folder.FullName).Count -eq 0) {
        Remove-Item -Path $folder.FullName -Force
        Write-Host "Removed empty folder: $($folder.FullName)"
    }
}
foreach ($folder in $orignalFolders) {
    # Get all files in the current 'renamed' folder
    $files = Get-ChildItem -Path $folder.FullName -File
    
    foreach ($file in $files) {
       
        # Remove the file
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Host "Removed file: $($file.Name)"
        }
        catch {
            Write-Host "Error Removing $($file.Name): $_" -ForegroundColor Red
        }
    }
    
    # Optional: Remove empty 'orignal' folder after moving files
    if ((Get-ChildItem -Path $folder.FullName).Count -eq 0) {
        Remove-Item -Path $folder.FullName -Force
        Write-Host "Removed empty folder: $($folder.FullName)"
    }
}
