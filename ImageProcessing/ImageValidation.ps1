$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptDir 'Logging.ps1')

function Test-IsImage {
    param (
        [string]$FilePath,
        [int]$FileIndex,
        [int]$TotalFiles
    )
    
    Write-Log "Starting Test-IsImage for $FilePath" -Level Info -Component "ImageValidation"
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    
    Write-Log "Validating image: $FilePath" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
    $img = $null
    try {
        $img = [System.Drawing.Image]::FromFile($FilePath)
        
        if ($img.Width -le 0 -or $img.Height -le 0) {
            throw "Invalid image dimensions"
        }
        
        if ($img.Size.IsEmpty) {
            throw "Empty image data"
        }
        
        $bitsPerPixel = switch ($img.PixelFormat) {
            ([System.Drawing.Imaging.PixelFormat]::Format1bppIndexed) { 1 }
            ([System.Drawing.Imaging.PixelFormat]::Format4bppIndexed) { 4 }
            ([System.Drawing.Imaging.PixelFormat]::Format8bppIndexed) { 8 }
            ([System.Drawing.Imaging.PixelFormat]::Format16bppGrayScale) { 16 }
            ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb) { 24 }
            ([System.Drawing.Imaging.PixelFormat]::Format32bppRgb) { 32 }
            ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb) { 32 }
            ([System.Drawing.Imaging.PixelFormat]::Format48bppRgb) { 48 }
            ([System.Drawing.Imaging.PixelFormat]::Format64bppArgb) { 64 }
            default { 0 }
        }
        
        if ($bitsPerPixel -eq 0) {
            throw "Unsupported pixel format"
        }
        
        Write-Log "Image validation successful" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "Image details:" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Dimensions: $($img.Width)x$($img.Height)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Pixel Format: $($img.PixelFormat) ($bitsPerPixel-bit)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Resolution: $($img.HorizontalResolution)x$($img.VerticalResolution) DPI" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "  - Raw Format: $($img.RawFormat.Guid)" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        
        $qualityScore = [math]::Min(100, [math]::Round(($img.Width * $img.Height * $bitsPerPixel) / 1000000))
        Write-Log "  - Quality Score: $qualityScore/100" -Level Info -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        
        return $true
    }
    catch [System.OutOfMemoryException] {
        Write-Log "File is too large to process: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    catch [System.IO.FileNotFoundException] {
        Write-Log "File not found: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    catch [System.UnauthorizedAccessException] {
        Write-Log "Access denied to file: $FilePath" -Level Error -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    catch {
        Write-Log "Invalid image file: $FilePath" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        Write-Log "Error details: $($_.Exception.Message)" -Level Warning -FileIndex $FileIndex -TotalFiles $TotalFiles -Component "ImageValidation"
        return $false
    }
    finally {
        if ($img) {
            $img.Dispose()
        }
    }
}