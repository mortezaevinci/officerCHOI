# Installs the free art tools this project uses, portable, into tools\art\.
#
#   powershell -ExecutionPolicy Bypass -File tools\art\install-art-tools.ps1
#   powershell -ExecutionPolicy Bypass -File tools\art\install-art-tools.ps1 -Only pixelorama
#
# Nothing here needs administrator rights and nothing touches the registry -
# each tool is a folder you can delete. They are gitignored (about 880 MB
# together), so this is how a new machine gets them.
#
#   Pixelorama      pixel art and animation. Built in Godot, so it behaves the
#                   way the rest of this project does. Sprites and portraits.
#   Material Maker  procedural textures, node-based. Floors, walls, surfaces.
#                   Also Godot-based. Exports PNG.
#   Krita           full painting application. For anything that wants a brush
#                   rather than a pixel grid - painted backgrounds, key art.
#
# All three are free and open source (MIT, MIT, GPL-3.0 respectively). Krita's
# GPL covers the application, not what you draw with it.

param(
    [ValidateSet("all", "pixelorama", "material-maker", "krita")]
    [string]$Only = "all",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dest = Join-Path $root "tools\art"

$tools = @(
    @{ Name = "pixelorama"
       Probe = "pixelorama\Pixelorama-Windows-64bit\Pixelorama.exe"
       Url   = "https://github.com/Orama-Interactive/Pixelorama/releases/download/v1.2.1/Pixelorama-Windows-64bit.zip" }
    @{ Name = "material-maker"
       Probe = "material-maker\material_maker_1_7_windows\material_maker.exe"
       Url   = "https://github.com/RodZill4/material-maker/releases/download/1.7/material_maker_1_7_windows.zip" }
    @{ Name = "krita"
       Probe = "krita\krita-x64-5.3.3\bin\krita.exe"
       Url   = "https://download.kde.org/stable/krita/5.3.3/krita-x64-5.3.3.zip" }
)

foreach ($tool in $tools) {
    if ($Only -ne "all" -and $Only -ne $tool.Name) { continue }

    $probe = Join-Path $dest $tool.Probe
    if ((Test-Path $probe) -and -not $Force) {
        Write-Host "$($tool.Name) already installed: $probe"
        continue
    }

    $target = Join-Path $dest $tool.Name
    $zip = Join-Path $env:TEMP "$($tool.Name).zip"

    Write-Host "`nDownloading $($tool.Name)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $tool.Url -OutFile $zip

    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Expand-Archive -Path $zip -DestinationPath $target -Force
    Remove-Item $zip

    Write-Host "Installed $probe" -ForegroundColor Green
}

Write-Host "`nSource art packs come from a separate script:" -ForegroundColor DarkGray
Write-Host "  python.exe tools\art\fetch_assets.py" -ForegroundColor DarkGray
