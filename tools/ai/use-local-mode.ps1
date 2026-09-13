# Points the AI agent's MCP config at the LOCAL server instead of the cloud.
#
#   powershell -ExecutionPolicy Bypass -File tools\ai\use-local-mode.ps1
#
# `godot-cli setup-mcp` writes a cloud URL (https://ai-game.dev/mcp/p/<pin>),
# which needs `godot-cli login` and routes your editor traffic through their
# service. `godot-cli configure --agent` rewrites the same config to talk to the
# local gamedev-mcp-server binary instead - no account, nothing leaves the box.
#
# Run this once. It rewrites game\.mcp.json, so restart your AI client after.

param(
    [string]$Agent = "claude-code"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$game = Join-Path $root "game"

# Resolve godot-cli. A PowerShell window opened BEFORE `npm install -g` has a
# stale PATH and will not see it even though it is installed, so fall back to
# the npm global prefix before giving up.
$cli = (Get-Command godot-cli -ErrorAction SilentlyContinue).Source
if (-not $cli) {
    $prefix = & npm config get prefix 2>$null
    if ($prefix) {
        $candidate = Join-Path $prefix.Trim() "godot-cli.cmd"
        if (Test-Path $candidate) { $cli = $candidate }
    }
}
if (-not $cli) {
    Write-Error "godot-cli not found. Run: npm install -g godot-cli (then open a NEW PowerShell window)"
}

& $cli configure --agent $Agent --path $game

# godot-cli writes game\.mcp.json, which only gets discovered if the AI client
# was started from game\. Mirror it to the repo root so it is found either way.
# Copied on every run, so the pin and port never drift between the two.
$written = Join-Path $game ".mcp.json"
if (Test-Path $written) {
    Copy-Item $written (Join-Path $root ".mcp.json") -Force
    Write-Host "Mirrored to $(Join-Path $root '.mcp.json')" -ForegroundColor DarkGray
}

Write-Host "`nRestart your AI client so it picks up the new MCP config." -ForegroundColor Yellow
Write-Host "Then, in two windows:" -ForegroundColor DarkGray
Write-Host "  tools\ai\start-mcp-server.ps1" -ForegroundColor DarkGray
Write-Host "  tools\ai\open-editor.ps1" -ForegroundColor DarkGray
