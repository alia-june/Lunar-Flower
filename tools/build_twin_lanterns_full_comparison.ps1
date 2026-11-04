param(
    [string]$NoEffectsPath,
    [string]$TwinLanternsFullPath,
    [string]$TwinLanternsFullLazaraPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$assetsDirectory = Join-Path $repositoryRoot 'Twin-Lanterns\assets'

if ([string]::IsNullOrWhiteSpace($NoEffectsPath)) {
    $NoEffectsPath = Join-Path $assetsDirectory 'twin-lanterns-full-no-effects.png'
}
if ([string]::IsNullOrWhiteSpace($TwinLanternsFullPath)) {
    $TwinLanternsFullPath = Join-Path $assetsDirectory 'twin-lanterns-full.png'
}
if ([string]::IsNullOrWhiteSpace($TwinLanternsFullLazaraPath)) {
    $TwinLanternsFullLazaraPath = Join-Path $assetsDirectory 'twin-lanterns-full-plus-lazara.png'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $assetsDirectory 'twin-lanterns-full-lazara-comparison.png'
}

Add-Type -AssemblyName System.Drawing

$sourcePaths = @(
    $NoEffectsPath,
    $TwinLanternsFullPath,
    $TwinLanternsFullLazaraPath
)
$bitmaps = @()
$output = $null

try {
    foreach ($sourcePath in $sourcePaths) {
        $resolvedPath = (Resolve-Path -LiteralPath $sourcePath).Path
        $bitmaps += [System.Drawing.Bitmap]::FromFile($resolvedPath)
    }

    $width = $bitmaps[0].Width
    $height = $bitmaps[0].Height
    foreach ($bitmap in $bitmaps) {
        if ($bitmap.Width -ne $width -or $bitmap.Height -ne $height) {
            throw 'All source captures must have identical dimensions.'
        }
    }

    $firstSplit = [int][Math]::Floor($width / 3.0)
    $secondSplit = $firstSplit * 2
    $regions = @(
        @{ X = 0; Width = $firstSplit },
        @{ X = $firstSplit; Width = $secondSplit - $firstSplit },
        @{ X = $secondSplit; Width = $width - $secondSplit }
    )

    $format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    $lockModeRead = [System.Drawing.Imaging.ImageLockMode]::ReadOnly
    $lockModeWrite = [System.Drawing.Imaging.ImageLockMode]::WriteOnly
    $output = New-Object System.Drawing.Bitmap($width, $height, $format)

    for ($index = 0; $index -lt $regions.Count; ++$index) {
        $region = $regions[$index]
        $rectangle = New-Object System.Drawing.Rectangle(
            $region.X, 0, $region.Width, $height)
        $decodedRegion = $bitmaps[$index].Clone($rectangle, $format)
        try {
            $sourceRectangle = New-Object System.Drawing.Rectangle(
                0, 0, $region.Width, $height)
            $sourceData = $decodedRegion.LockBits(
                $sourceRectangle, $lockModeRead, $format)
            $outputData = $output.LockBits(
                $rectangle, $lockModeWrite, $format)
            try {
                $rowBytes = $region.Width * 4
                $row = New-Object byte[] $rowBytes
                for ($y = 0; $y -lt $height; ++$y) {
                    $sourcePointer = [IntPtr]::Add(
                        $sourceData.Scan0, $y * $sourceData.Stride)
                    $outputPointer = [IntPtr]::Add(
                        $outputData.Scan0, $y * $outputData.Stride)
                    [Runtime.InteropServices.Marshal]::Copy(
                        $sourcePointer, $row, 0, $rowBytes)
                    [Runtime.InteropServices.Marshal]::Copy(
                        $row, 0, $outputPointer, $rowBytes)
                }
            }
            finally {
                $decodedRegion.UnlockBits($sourceData)
                $output.UnlockBits($outputData)
            }
        }
        finally {
            $decodedRegion.Dispose()
        }
    }

    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $output.Save($resolvedOutput, [System.Drawing.Imaging.ImageFormat]::Png)
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedOutput).Hash
    Write-Output "output=$resolvedOutput"
    Write-Output "sha256=$hash"
    Write-Output "dimensions=${width}x${height}"
    Write-Output "splits=0-$firstSplit,$firstSplit-$secondSplit,$secondSplit-$width"
}
finally {
    if ($null -ne $output) {
        $output.Dispose()
    }
    foreach ($bitmap in $bitmaps) {
        $bitmap.Dispose()
    }
}
