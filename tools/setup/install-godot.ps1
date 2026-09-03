# Installs the exact Godot editor and export templates this project builds with.
#
#   powershell -ExecutionPolicy Bypass -File tools\setup\install-godot.ps1
#
# The editor lands in tools\godot (kept out of git). Export templates go where
# Godot looks for them, in %APPDATA%\Godot\export_templates.
#
# Everyone on the project runs the same version. A different Godot build can
# silently change how scenes are saved, which turns every .tscn into a diff.

param(
    [string]$Version = "4.7.2-stable",
    [switch]$SkipTemplates,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$root       = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$godotDir   = Join-Path $root "tools\godot"
$editorExe  = Join-Path $godotDir "Godot_v${Version}_win64.exe"
$base       = "https://github.com/godotengine/godot/releases/download/$Version"

New-Item -ItemType Directory -Force -Path $godotDir | Out-Null

# --- editor ------------------------------------------------------------------

if ((Test-Path $editorExe) -and -not $Force) {
    Write-Host "Editor already present: $editorExe"
} else {
    $zip = Join-Path $env:TEMP "godot_$Version.zip"
    Write-Host "Downloading Godot $Version editor..."
    Invoke-WebRequest -Uri "$base/Godot_v${Version}_win64.exe.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $godotDir -Force
    Remove-Item $zip
    Write-Host "Installed $editorExe"
}

# --- export templates --------------------------------------------------------
# Needed only to produce builds. Skip them if you are just writing content.

if ($SkipTemplates) {
    Write-Host "Skipping export templates (-SkipTemplates)."
    exit 0
}

$versionDir = $Version -replace "-", "."          # 4.7.2-stable -> 4.7.2.stable
$templates  = Join-Path $env:APPDATA "Godot\export_templates\$versionDir"

if ((Test-Path (Join-Path $templates "windows_release_x86_64.exe")) -and -not $Force) {
    Write-Host "Export templates already installed: $templates"
    exit 0
}

$tpz     = Join-Path $env:TEMP "godot_templates_$Version.tpz"
$staging = Join-Path $env:TEMP "godot_templates_$Version"

Write-Host "Downloading export templates (about 1 GB, this takes a while)..."
Invoke-WebRequest -Uri "$base/Godot_v${Version}_export_templates.tpz" -OutFile $tpz

# A .tpz is a zip containing a single "templates" folder.
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
Expand-Archive -Path $tpz -DestinationPath $staging -Force

New-Item -ItemType Directory -Force -Path (Split-Path $templates) | Out-Null
if (Test-Path $templates) { Remove-Item $templates -Recurse -Force }
Move-Item (Join-Path $staging "templates") $templates

Remove-Item $tpz
Remove-Item $staging -Recurse -Force
Write-Host "Installed export templates: $templates"
