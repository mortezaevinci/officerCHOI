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
#
# IF YOUR AI CLIENT RUNS IN WSL: this server binds Windows loopback only
# (MCP_BIND defaults to "loopback"), and default WSL NAT networking cannot reach
# it - the Hyper-V firewall DROPS inbound to host ports from the WSL subnet, so
# even MCP_BIND=any times out rather than connecting. The fix is mirrored
# networking, not a firewall hole: put
#     [wsl2]
#     networkingMode=mirrored
# in C:\Users\<you>\.wslconfig, then run `wsl --shutdown`. After that,
# http://localhost:24777 resolves from inside WSL and the server stays bound to
# loopback with nothing exposed on a network interface.
Write-Host "Starting gamedev-mcp-server on http://localhost:$Port" -ForegroundColor Cyan
Write-Host "Leave this window open. Ctrl+C to stop.`n" -ForegroundColor DarkGray

& $server --port $Port --auth none
