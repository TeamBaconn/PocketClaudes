# Pocket Claudes

A Claude Code plugin that visualizes live Claude Code sessions as desktop NPCs. Each running session spawns an on-screen character that animates to reflect what the session is doing — reading, writing, running commands, browsing, or waiting for your attention.

Requires the PocketClaudes game (Unity 6, built separately). Works on Windows, macOS, and Linux.

## Install

```bash
claude plugin marketplace add TeamBaconn/PocketClaudes
claude plugin install pocket-claudes@pocket-claudes
```

For local development:

```bash
claude --plugin-dir <path-to-this-repo>
```

## Setup

Launch the PocketClaudes game yourself before (or any time during) a Claude Code session. The plugin does not start the game — it only forwards events to a game that is already running. Events sent while the game is closed are dropped silently.

## How it works

The plugin registers hooks for these Claude Code events:

- `SessionStart`, `SessionEnd`
- `UserPromptSubmit`
- `PreToolUse`, `PostToolUse`, `PostToolUseFailure`
- `PermissionRequest`, `PermissionDenied`
- `Elicitation`, `ElicitationResult`
- `SubagentStart`, `SubagentStop`
- `Notification` (only the `idle_prompt` matcher)
- `Stop`, `StopFailure`

Each hook normalizes the event JSON into a flat `IpcCommand` and POSTs it to the game over loopback HTTP (port 1604). The hook command tries bash first (macOS/Linux), falling back to PowerShell (Windows).

## Privacy & security

**Your prompts, code, and tool output never leave Claude Code.** The hook forwards only a fixed set of metadata fields to the game — nothing more.

Sent to the game:

- `eventName`, `sessionId`, `agentId`, `agentType` — event type + opaque IDs
- `toolName`, `toolUseId` — which tool fired (e.g. `Read`, `Bash`), not its arguments
- `model` — model name
- `cwd` — current working directory (used as on-NPC label only)
- `hostPid` — PID of your terminal/IDE window, so clicking the NPC brings *that* window to the front (the only reason the game needs it)

**Never sent:** your prompt text, tool inputs (Bash commands, file paths, edit contents), tool results (file contents, command output), Claude's responses, error messages, MCP elicitation values, or the transcript path.

The game listens only on `127.0.0.1:1604` (loopback) and makes no outbound network connections. You can verify with `netstat` / `lsof` or any network monitor.

Audit the exact fields extracted in `scripts/hook-event.sh` and `scripts/hook-event.ps1` — both are under 100 lines.

## Structure

```
pocket-claudes-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   └── hooks.json           # Hook registrations
└── scripts/
    ├── hook-event.sh        # macOS/Linux: normalizes hook JSON → IpcCommand
    └── hook-event.ps1       # Windows: normalizes hook JSON → IpcCommand
```

## License

MIT
