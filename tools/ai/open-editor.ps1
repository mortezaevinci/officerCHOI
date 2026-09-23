# Opens the project in the .NET edition of Godot, connected to the local MCP
# server, so an AI agent can drive the editor.
#
#   powershell -ExecutionPolicy Bypass -File tools\ai\open-editor.ps1
#
# Start tools\ai\start-mcp-server.ps1 first, in its own window.
#
# Use the .NET editor whenever you want the addon live. For ordinary work -
# writing dialogue, running the game, running tests - the standard editor in
# C:\temp\godotsetup\engine\godot is faster and quieter.

param(
    [int]$Port = 24777,
    [ValidateSet("Custom", "Cloud")]
    [string]$Mode = "Custom",
    [switch]$NoWait
)

$ErrorActionPreference = "Stop"

$root   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$game   = Join-Path $root "game"
$editor = "C:\temp\godotsetup\engine\godot-mono\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"

if (-not (Test-Path $editor)) {
    Write-Error "The .NET Godot editor is missing. Run tools\setup\install-godot.ps1 -Mono"
}

$godotCli = Get-Command godot-cli -ErrorAction SilentlyContinue
if (-not $godotCli) {
    Write-Error "godot-cli not found. Run: npm install -g godot-cli"
}

if ($Mode -eq "Custom") {
    # Fail early with a useful message rather than letting the editor sit there
    # retrying a connection that is never going to come up.
    try {
        Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 3 -UseBasicParsing | Out-Null
    } catch [System.Net.WebException] {
        if ($_.Exception.Response -eq $null) {
            Write-Warning "Nothing is listening on http://localhost:$Port."
            Write-Warning "Start it first:  tools\ai\start-mcp-server.ps1"
        }
    } catch {
        # A non-200 answer still means something is listening, which is enough.
    }

    godot-cli open --path $game --editor-path $editor `
        --mode Custom --url "http://localhost:$Port" --auth None
} else {
    # Cloud mode routes through ai-game.dev and needs `godot-cli login` first.
    godot-cli open --path $game --editor-path $editor --mode Cloud
}

if (-not $NoWait) {
    Write-Host "`nWaiting for the plugin to answer..." -ForegroundColor Cyan
    godot-cli wait-for-ready $game
    godot-cli status $game
}
