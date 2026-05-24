# Pocket Claudes

A Claude Code plugin that visualizes live Claude Code sessions as desktop NPCs. Each running session spawns an on-screen character that animates to reflect what the session is doing — reading, writing, running commands, browsing, or waiting for your attention.

Requires the PocketClaudes game (Unity 6, built separately). Works on Windows, macOS, and Linux.

## Install

```bash
claude --plugin-dir ./pocket-claudes-plugin
```

Or install from a marketplace once published:

```bash
claude plugin install pocket-claudes@<marketplace>
```

## Setup

When you enable the plugin, it prompts for the path to your built PocketClaudes executable. This lets `SessionStart` cold-start the game automatically.

If you skip the prompt, set the `POCKETCLAUDES_EXE` environment variable instead.

## How it works

The plugin registers hooks for these Claude Code events:

| Hook event           | Game action                                                          |
|----------------------|----------------------------------------------------------------------|
| `SessionStart`       | Spawn NPC for the session (cold-starts game if needed)               |
| `SessionEnd`         | Despawn NPC; game self-closes when registry empties                  |
| `UserPromptSubmit`   | NPC → Thinking                                                       |
| `PreToolUse`         | NPC → tool animation (read / write / run / browse)                   |
| `PostToolUse`        | NPC → Thinking                                                       |
| `PostToolUseFailure` | NPC → Thinking                                                       |
| `PermissionRequest`  | NPC → Attention (permission dialog visible)                          |
| `PermissionDenied`   | NPC → Thinking                                                       |
| `Elicitation`        | NPC → Attention (MCP server requesting input)                        |
| `ElicitationResult`  | NPC → Thinking                                                       |
| `SubagentStart`      | Spawn a mini follower NPC                                            |
| `SubagentStop`       | Despawn the mini NPC                                                 |
| `Stop`               | NPC → Idle                                                           |
| `StopFailure`        | NPC → Idle                                                           |

Each hook normalizes the event JSON into a flat `IpcCommand` and delivers it to the game over loopback HTTP (port 1604). If the game isn't running, only `SessionStart` may launch it via `--event` argument. The hook command tries bash first (macOS/Linux), falling back to PowerShell (Windows).

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
