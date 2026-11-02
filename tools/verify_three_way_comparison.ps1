param(
    [Parameter(Mandatory = $true)] [string] $NoEffect,
    [Parameter(Mandatory = $true)] [string] $TwinLanterns,
    [Parameter(Mandatory = $true)] [string] $LazaraAndTwinLanterns,
    [Parameter(Mandatory = $true)] [string] $Output,
    [Parameter(Mandatory = $true)] [string] $Manifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Get-PixelBytes([System.Drawing.Bitmap] $Bitmap, [int] $X, [int] $Width) {
    $rectangle = [System.Drawing.Rectangle]::new($X, 0, $Width, $Bitmap.Height)
    $data = $Bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $bytes = [byte[]]::new($Width * $Bitmap.Height * 4)
        $rowBytes = $Width * 4
        for ($y = 0; $y -lt $Bitmap.Height; $y++) {
            [Runtime.InteropServices.Marshal]::Copy(
                [IntPtr]::Add($data.Scan0, $y * $data.Stride),
                $bytes,
                $y * $rowBytes,
                $rowBytes
            )
        }
        return $bytes
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

function Get-ByteHash([byte[]] $Bytes) {
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    )
}

$sourcePaths = @($NoEffect, $TwinLanterns, $LazaraAndTwinLanterns)
$sources = @()
$outputBitmap = $null
try {
    foreach ($path in $sourcePaths) {
        $sources += [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $path))
    }
    $outputBitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Output))

    $width = $outputBitmap.Width
    $height = $outputBitmap.Height
    foreach ($source in $sources) {
        if ($source.Width -ne $width -or $source.Height -ne $height) {
            throw 'Source and output dimensions differ.'
        }
    }

    $boundaries = @(0, [Math]::Floor($width / 3), [Math]::Floor(($width * 2) / 3), $width)
    for ($index = 0; $index -lt 3; $index++) {
        $x = $boundaries[$index]
        $regionWidth = $boundaries[$index + 1] - $x
        $sourceBytes = Get-PixelBytes $sources[$index] $x $regionWidth
        $outputBytes = Get-PixelBytes $outputBitmap $x $regionWidth
        if ((Get-ByteHash $sourceBytes) -ne (Get-ByteHash $outputBytes)) {
            throw "Region $index does not exactly match its decoded source pixels."
        }
    }

    $evidence = Get-Content -Raw -LiteralPath $Manifest | ConvertFrom-Json
    if (-not $evidence.all_regions_exact) {
        throw 'Manifest does not record exact region matches.'
    }
    if ($evidence.output_sha256 -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $Output).Hash) {
        throw 'Output hash does not match the evidence manifest.'
    }

    Write-Output "Verified 3/3 source regions at ${width}x${height}."
}
finally {
    if ($null -ne $outputBitmap) {
        $outputBitmap.Dispose()
    }
    foreach ($source in $sources) {
        $source.Dispose()
    }
}

