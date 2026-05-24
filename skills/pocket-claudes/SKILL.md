---
name: pocket-claudes
description: Use when the user asks about installing, configuring, troubleshooting, or understanding the Pocket Claudes plugin — the Claude Code plugin that visualizes live sessions as desktop NPCs by pairing with the PocketClaudes Unity 6 overlay game.
---

# Pocket Claudes

## What it is

Claude Code plugin. Pairs with the **PocketClaudes** Unity 6 desktop overlay game (separate download). Each running Claude Code session → one NPC walking on the user's desktop. Hooks here forward event metadata over loopback HTTP; the game renders the NPCs and animates them per event.

The plugin alone does nothing visible — the game is the renderer. The game alone does nothing — the plugin is its only data source.

## How it works

- `hooks/hooks.json` registers 14 hook events. Each event runs one command: `bash scripts/hook-event.sh || powershell ... scripts/hook-event.ps1` — bash first (macOS/Linux), PowerShell fallback (Windows). No external runtime dep.
- The script reads hook JSON from stdin, extracts a fixed metadata set, walks the parent-process chain for `hostPid`, builds a flat versioned `IpcCommand`, and `POST`s to `http://127.0.0.1:1604/`.
- If the POST fails the event is dropped. The plugin never launches the game — the user is responsible for starting it. So events fired before the game is running (or after a manual close) silently no-op.
- Game enforces single-instance via a named Mutex; if a second process starts it exits immediately.
- Game's dispatcher is **self-healing**: unknown `session_id` lazily spawns the NPC; unknown `agent_id` lazily spawns a mini NPC; duplicate `SessionStart` reuses. So `SessionStart` is an optimization, never a precondition — the first event delivered to a running game spawns the NPC regardless of type.

## Privacy

Hook forwards only: `eventName`, `sessionId`, `agentId`, `agentType`, `toolName`, `toolUseId`, `model`, `cwd`, `hostPid`. **Never** prompt text, tool inputs/results, file contents, command output, Claude responses, or transcript path. Game listens on `127.0.0.1:1604` only — no outbound network. Both scripts are <100 lines; audit them directly.

## Troubleshooting

- **No NPC on first session.** The game isn't running. Launch the PocketClaudes executable, then trigger any hook event (e.g. send a prompt) — the next event spawns the NPC via the self-healing dispatcher.
- **Game crashes immediately with a dialog.** Port `1604` is in use (fixed, no discovery). Kill the conflicting process; check `netstat -ano | findstr :1604` (Windows) or `lsof -i :1604` (mac/Linux).
- **NPC stuck in wrong state.** Hook event missed or out of order. Next event self-corrects via the idempotent dispatcher; no manual fix.
- **Clicking NPC focuses the wrong window.** `hostPid` resolution failed. Linux needs `xdotool`; macOS uses `osascript`; Windows uses `Win32_Process`. Install missing tool and restart the session.
