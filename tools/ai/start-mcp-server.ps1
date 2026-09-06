# Starts the local ai-game.dev MCP server.
#
#   powershell -ExecutionPolicy Bypass -File tools\ai\start-mcp-server.ps1
#
# Leave this window open while you work. It is what the AI agent talks to; the
# Godot editor connects to it from the other side.
#
# Local mode means no account, no sign-in, and nothing about this project
# leaving the machine. The alternative is cloud mode through ai-game.dev, which
# needs `godot-cli login` - see docs\dev\ai-game-dev.md.

param(
    [int]$Port = 24777
)

$ErrorActionPreference = "Stop"

$root   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$server = Join-Path $root "game\.ai-game-dev\server\gamedev-mcp-server.exe"

if (-not (Test-Path $server)) {
    Write-Error @"
Local server not installed. Run:
    godot-cli install-plugin $root\game --with-server
"@
}

# Port 8080 (the server's own default) is blocked on this machine - Windows
# reserves ranges for Hyper-V/WSL and binding it fails with socket error 10013.
# 24777 is outside every reserved range here; check with:
#     netsh int ipv4 show excludedportrange protocol=tcp
Write-Host "Starting gamedev-mcp-server on http://localhost:$Port" -ForegroundColor Cyan
Write-Host "Leave this window open. Ctrl+C to stop.`n" -ForegroundColor DarkGray

& $server --port $Port --auth none
