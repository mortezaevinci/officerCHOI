# Installs the exact Godot editors and export templates this project builds with.
#
#   powershell -ExecutionPolicy Bypass -File tools\setup\install-godot.ps1
#   powershell -ExecutionPolicy Bypass -File tools\setup\install-godot.ps1 -Mono
#   powershell -ExecutionPolicy Bypass -File tools\setup\install-godot.ps1 -All
#
# Two editors, on purpose:
#
#   C:\temp\godotsetup\engine\godot\        standard build. Day-to-day work: writing, playing,
#                       running tests. Fast, and no .NET startup cost.
#   C:\temp\godotsetup\engine\godot-mono\   .NET build. Required for the ai-game.dev godot_mcp
#                       addon (it is C# and will not load in the standard
#                       build) and used for producing release builds, because
#                       the project has a .csproj.
#
# Everyone on the project runs the same versions. A different Godot build can
# silently change how scenes are saved, which turns every .tscn into a diff.

param(
    [string]$Version = "4.7.2-stable",
    [switch]$Mono,          # install the .NET edition instead of the standard one
    [switch]$All,           # install both
    [switch]$SkipTemplates,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$base = "https://github.com/godotengine/godot/releases/download/$Version"
$versionDir = $Version -replace "-", "."      # 4.7.2-stable -> 4.7.2.stable

$editions = @()
if ($All) { $editions = @($false, $true) }
elseif ($Mono) { $editions = @($true) }
else { $editions = @($false) }

foreach ($isMono in $editions) {

    $label   = if ($isMono) { ".NET (mono)" } else { "standard" }
    $dir     = if ($isMono) { "C:\temp\godotsetup\engine\godot-mono" } else { "C:\temp\godotsetup\engine\godot" }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Write-Host "`n=== Godot $Version - $label ===" -ForegroundColor Cyan

    # --- editor ---------------------------------------------------------------
    # The mono zip unpacks into its own subfolder; the standard zip does not.
    $editorExe = if ($isMono) {
        Join-Path $dir "Godot_v${Version}_mono_win64\Godot_v${Version}_mono_win64.exe"
    } else {
        Join-Path $dir "Godot_v${Version}_win64.exe"
    }

    if ((Test-Path $editorExe) -and -not $Force) {
        Write-Host "Editor already present: $editorExe"
    } else {
        $asset = if ($isMono) { "Godot_v${Version}_mono_win64.zip" } else { "Godot_v${Version}_win64.exe.zip" }
        $zip = Join-Path $env:TEMP $asset
        Write-Host "Downloading $asset ..."
        Invoke-WebRequest -Uri "$base/$asset" -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $dir -Force
        Remove-Item $zip
        Write-Host "Installed $editorExe" -ForegroundColor Green
    }

    # --- export templates -----------------------------------------------------
    # Only needed to produce builds. Skip if you are just writing content.
    if ($SkipTemplates) {
        Write-Host "Skipping export templates (-SkipTemplates)."
        continue
    }

    # Godot keeps the two sets side by side: "4.7.2.stable" and "4.7.2.stable.mono".
    $templateDir = Join-Path $env:APPDATA "Godot\export_templates\$versionDir$(if ($isMono) { '.mono' })"
    $probe = Join-Path $templateDir "windows_release_x86_64.exe"

    if ((Test-Path $probe) -and -not $Force) {
        Write-Host "Export templates already installed: $templateDir"
        continue
    }

    $tpzAsset = if ($isMono) { "Godot_v${Version}_mono_export_templates.tpz" } else { "Godot_v${Version}_export_templates.tpz" }
    $tpz      = Join-Path $env:TEMP $tpzAsset
    $staging  = Join-Path $env:TEMP "godot_templates_staging"

    Write-Host "Downloading $tpzAsset (about 1 GB, this takes a while)..."
    Invoke-WebRequest -Uri "$base/$tpzAsset" -OutFile $tpz

    # A .tpz is a zip containing a single "templates" folder.
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    Expand-Archive -Path $tpz -DestinationPath $staging -Force

    New-Item -ItemType Directory -Force -Path (Split-Path $templateDir) | Out-Null
    if (Test-Path $templateDir) { Remove-Item $templateDir -Recurse -Force }
    Move-Item (Join-Path $staging "templates") $templateDir

    Remove-Item $tpz
    Remove-Item $staging -Recurse -Force
    Write-Host "Installed export templates: $templateDir" -ForegroundColor Green
}

Write-Host "`nDone." -ForegroundColor Green
