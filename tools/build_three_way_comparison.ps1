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

function Open-NormalizedBitmap([string] $Path) {
    $source = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Path))
    try {
        $bitmap = [System.Drawing.Bitmap]::new(
            $source.Width,
            $source.Height,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.DrawImageUnscaled($source, 0, 0)
        }
        finally {
            $graphics.Dispose()
        }
        return $bitmap
    }
    finally {
        $source.Dispose()
    }
}

function Copy-VerticalRegion(
    [System.Drawing.Bitmap] $Source,
    [System.Drawing.Bitmap] $Destination,
    [int] $X,
    [int] $Width
) {
    $rectangle = [System.Drawing.Rectangle]::new(0, 0, $Source.Width, $Source.Height)
    $sourceData = $Source.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $destinationData = $Destination.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $rowBytes = $Width * 4
        $row = [byte[]]::new($rowBytes)
        for ($y = 0; $y -lt $Source.Height; $y++) {
            $sourcePointer = [IntPtr]::Add($sourceData.Scan0, ($y * $sourceData.Stride) + ($X * 4))
            $destinationPointer = [IntPtr]::Add($destinationData.Scan0, ($y * $destinationData.Stride) + ($X * 4))
            [Runtime.InteropServices.Marshal]::Copy($sourcePointer, $row, 0, $rowBytes)
            [Runtime.InteropServices.Marshal]::Copy($row, 0, $destinationPointer, $rowBytes)
        }
    }
    finally {
        $Source.UnlockBits($sourceData)
        $Destination.UnlockBits($destinationData)
    }
}

function Get-RegionHash(
    [System.Drawing.Bitmap] $Bitmap,
    [int] $X,
    [int] $Width
) {
    $rectangle = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $rowBytes = $Width * 4
            $row = [byte[]]::new($rowBytes)
            for ($y = 0; $y -lt $Bitmap.Height; $y++) {
                $pointer = [IntPtr]::Add($data.Scan0, ($y * $data.Stride) + ($X * 4))
                [Runtime.InteropServices.Marshal]::Copy($pointer, $row, 0, $rowBytes)
                [void] $sha256.TransformBlock($row, 0, $row.Length, $null, 0)
            }
            [void] $sha256.TransformFinalBlock([byte[]]::new(0), 0, 0)
            return [Convert]::ToHexString($sha256.Hash)
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

$inputs = @(
    @{ Label = 'No Effect'; Path = $NoEffect },
    @{ Label = 'Twin Lanterns Only'; Path = $TwinLanterns },
    @{ Label = 'Lazara + Twin Lanterns'; Path = $LazaraAndTwinLanterns }
)

$bitmaps = @()
$outputBitmap = $null
try {
    foreach ($input in $inputs) {
        $bitmaps += Open-NormalizedBitmap $input.Path
    }

    $width = $bitmaps[0].Width
    $height = $bitmaps[0].Height
    foreach ($bitmap in $bitmaps) {
        if ($bitmap.Width -ne $width -or $bitmap.Height -ne $height) {
            throw 'All comparison sources must have identical dimensions.'
        }
    }

    $firstBoundary = [Math]::Floor($width / 3)
    $secondBoundary = [Math]::Floor(($width * 2) / 3)
    $regions = @(
        @{ X = 0; Width = $firstBoundary },
        @{ X = $firstBoundary; Width = $secondBoundary - $firstBoundary },
        @{ X = $secondBoundary; Width = $width - $secondBoundary }
    )

    $outputBitmap = [System.Drawing.Bitmap]::new(
        $width,
        $height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    for ($index = 0; $index -lt 3; $index++) {
        Copy-VerticalRegion $bitmaps[$index] $outputBitmap $regions[$index].X $regions[$index].Width
    }

    $outputDirectory = Split-Path -Parent $Output
    if ($outputDirectory) {
        [void] (New-Item -ItemType Directory -Force -Path $outputDirectory)
    }
    $manifestDirectory = Split-Path -Parent $Manifest
    if ($manifestDirectory) {
        [void] (New-Item -ItemType Directory -Force -Path $manifestDirectory)
    }

    $outputBitmap.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)

    $regionEvidence = @()
    for ($index = 0; $index -lt 3; $index++) {
        $sourceRegionHash = Get-RegionHash $bitmaps[$index] $regions[$index].X $regions[$index].Width
        $outputRegionHash = Get-RegionHash $outputBitmap $regions[$index].X $regions[$index].Width
        $regionEvidence += [ordered]@{
            label = $inputs[$index].Label
            source_file = [IO.Path]::GetFileName($inputs[$index].Path)
            source_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $inputs[$index].Path).Hash
            x_start = $regions[$index].X
            x_end_exclusive = $regions[$index].X + $regions[$index].Width
            decoded_region_sha256 = $sourceRegionHash
            output_region_sha256 = $outputRegionHash
            exact_match = ($sourceRegionHash -eq $outputRegionHash)
        }
    }

    $evidence = [ordered]@{
        schema = 'lunar-flower-three-way-comparison-v1'
        composition = 'Vertical thirds copied without resize, filtering, or generated pixels.'
        width = $width
        height = $height
        pixel_format = '32bpp ARGB after deterministic decode'
        output_file = [IO.Path]::GetFileName($Output)
        output_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Output).Hash
        regions = $regionEvidence
        all_regions_exact = -not ($regionEvidence.exact_match -contains $false)
    }
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Manifest -Encoding utf8
}
finally {
    if ($null -ne $outputBitmap) {
        $outputBitmap.Dispose()
    }
    foreach ($bitmap in $bitmaps) {
        $bitmap.Dispose()
    }
}

