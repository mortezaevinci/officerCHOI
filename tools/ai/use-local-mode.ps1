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

if (-not (Get-Command godot-cli -ErrorAction SilentlyContinue)) {
    Write-Error "godot-cli not found. Run: npm install -g godot-cli"
}

godot-cli configure --agent $Agent --path $game

Write-Host "`nRestart your AI client so it picks up the new MCP config." -ForegroundColor Yellow
Write-Host "Then, in two windows:" -ForegroundColor DarkGray
Write-Host "  tools\ai\start-mcp-server.ps1" -ForegroundColor DarkGray
Write-Host "  tools\ai\open-editor.ps1" -ForegroundColor DarkGray
