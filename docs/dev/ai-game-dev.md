# ai-game.dev (Godot MCP)

[ai-game.dev](https://ai-game.dev) is an MCP bridge that lets an AI agent drive
the Godot **editor** directly — create and edit nodes, open and save scenes,
mutate resources, read and write scripts, and take screenshots of the viewport
so it can see what it did. Apache-2.0, and the plugin works against a local
server or their hosted one.

Installed here: **godot_mcp addon v0.22.0**, **godot-cli 0.22.0**,
**gamedev-mcp-server 9.2.5**.

- Upstream: <https://github.com/IvanMurzak/Godot-MCP>
- Tool catalogue: <https://ai-game.dev/docs/tools/godot>

---

## What it cost us, up front

The addon is written in C# and, quoting its README:

> Godot-MCP requires the **mono (C#/.NET)** build of Godot — the standard
> (GDScript-only) build cannot compile the addon.

Our game is GDScript and was on the standard build. So installing it meant:

| Change | Where |
|---|---|
| The project is now also a C# project | `game/OfficerChoi.csproj` |
| `[dotnet]` section and the `C#` feature flag | `game/project.godot` |
| A second editor, the .NET edition | `tools/godot-mono/` |
| A second set of export templates, `4.7.2.stable.mono` | `%APPDATA%\Godot\...` |
| Builds go through the .NET toolchain | `tools/build/build.ps1` |
| A NuGet workaround for this machine | `game/nuget.config` |

**No gameplay code moved to C#, and none should.** The `.csproj` exists so the
addon can compile. The game stays GDScript.

Verified after the change: the 35-test suite still passes on both editors, and
a Windows release build still exports, runs, and contains the dialogue files.

Upstream says it supports "Godot 4.3+ … 4.4, 4.5 work". We are on 4.7.2, which
is past what they test. It compiles with three deprecation warnings about
`AddControlToDock`/`RemoveControlFromDocks` and works.

---

## Running it

Two windows, in this order.

**1. Start the local server** — leave it open:

```powershell
powershell -ExecutionPolicy Bypass -File tools\ai\start-mcp-server.ps1
```

**2. Open the .NET editor, connected to it:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\ai\open-editor.ps1
```

That waits for the plugin to answer and prints the status. Once it says ready,
the agent's tools work against the live editor.

Check any time:

```powershell
godot-cli status C:\temp\officerchoi\game
```

---

## Local vs cloud — and the one step left

`godot-cli setup-mcp` wrote `game/.mcp.json` pointing at the **cloud** endpoint:

```json
{ "mcpServers": { "ai-game-developer": {
    "type": "http", "url": "https://ai-game.dev/mcp/p/e96f2dd5" } } }
```

Cloud mode needs a sign-in, and it routes editor traffic through their service:

```powershell
godot-cli login
```

That opens a browser for an OAuth device-code flow and saves a machine-wide
credential the editor picks up automatically.

**Local mode is the better default here** — no account, and nothing about this
project leaves the machine. Switching is one command:

```powershell
powershell -ExecutionPolicy Bypass -File tools\ai\use-local-mode.ps1
```

It rewrites `game/.mcp.json` to point at `localhost`. Restart the AI client
afterwards so it reloads the config.

Pick one. Both work; local asks less of you and shares less.

---

## Ports

The server's own default is 8080, which **does not work on this machine** —
Windows reserves ranges for Hyper-V/WSL and binding fails with socket error
10013. Everything here uses **24777**, which is outside every reserved range.
To check after a Windows update moves them:

```powershell
netsh int ipv4 show excludedportrange protocol=tcp
```

---

## Which editor to use

| Doing | Editor |
|---|---|
| Writing dialogue, editing scenes, playing the game | `tools\godot\` (standard) |
| Running tests | `tools\godot\` — `run-tests.ps1` |
| Letting the AI agent drive the editor | `tools\godot-mono\` — `open-editor.ps1` |
| Producing a release build | `tools\godot-mono\` — `build.ps1` |

The standard editor still opens the project perfectly well and ignores the C#
side, so it stays the fast path for everyday work.

If the addon's connection errors ever clutter a headless run, the scripts
already set it, but by hand it is:

```powershell
$env:GODOT_MCP_LOG_LEVEL = "None"
```

---

## What is committed, and what is not

| Committed | Ignored |
|---|---|
| `game/addons/godot_mcp/` (2.5 MB — everyone gets the same version) | `game/.ai-game-dev/` (99 MB server binary, logs, **credentials**) |
| `game/.claude/skills/` (42 generated per-tool skill docs) | `game/.godot-mcp/` (local tool enable/disable state) |
| `game/.mcp.json`, `game/OfficerChoi.csproj`, `game/nuget.config` | `tools/godot-mono/` |

The credential file is why `game/.ai-game-dev/` must stay ignored.

---

## Turning it off

It comes out cleanly:

```powershell
godot-cli remove-plugin C:\temp\officerchoi\game
```

Then delete `game/addons/godot_mcp/`, `game/OfficerChoi.csproj`,
`game/.mcp.json`, `game/.ai-game-dev/`, the `[dotnet]` section and the `C#`
feature flag from `game/project.godot`, and point `build.ps1` back at
`tools\godot`. The game itself never depended on any of it.

---

## About "creating models"

Worth being precise, because the name suggests more than it does. These tools
drive the **editor**: nodes, scenes, resources, scripts, the filesystem, the
viewport. They are not a 3D-model or texture generator, and this is a 2D game
in any case.

Where it will actually earn its keep here:

- Laying out a new room — floor, walls, spawn markers, interactables — from a
  description, instead of hand-editing `.tscn` files.
- Wiring a desk up: an Interactable with the right action, target scene and
  prompt offsets.
- Looking at the result. It can screenshot the viewport and correct itself,
  which is the part that makes the rest worth having.

Art still has to come from somewhere else. `docs/dev/adding-content.md` says
where the files go.
