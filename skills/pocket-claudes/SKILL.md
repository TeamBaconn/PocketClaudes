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
- If POST fails AND event is `SessionStart`: launches `$game_exe --event '<json>'` to cold-start the game. Game exe resolved from `CLAUDE_PLUGIN_OPTION_GAME_EXE` (userConfig prompt) → `POCKETCLAUDES_EXE` env var. Other failing events drop silently — respects a manual game close, no relaunch on a stray tool event.
- Game enforces single-instance via named Mutex; a second process forwards `--event` to the running one over HTTP, then exits. Launch path is race-safe.
- Game's dispatcher is **self-healing**: unknown `session_id` lazily spawns the NPC; unknown `agent_id` lazily spawns a mini NPC; duplicate `SessionStart` reuses. So `SessionStart` is an optimization, never a precondition.

## Auto-start (recommended)

For the game to cold-start automatically on `SessionStart`, `POCKETCLAUDES_EXE` must point at the built game executable. You can ask Claude to set this up for you — e.g. *"set POCKETCLAUDES_EXE to <path-to-PocketClaudes.exe>"* — and it will configure the env var (user/system scope on Windows, shell rc on macOS/Linux). Without it, the game won't auto-launch and events drop until you start the game manually.

## Privacy

Hook forwards only: `eventName`, `sessionId`, `agentId`, `agentType`, `toolName`, `toolUseId`, `model`, `cwd`, `hostPid`. **Never** prompt text, tool inputs/results, file contents, command output, Claude responses, or transcript path. Game listens on `127.0.0.1:1604` only — no outbound network. Both scripts are <100 lines; audit them directly.

## Troubleshooting

- **No NPC on first session.** `game_exe` not configured. Set `POCKETCLAUDES_EXE` (see Auto-start) or re-enable plugin and answer the userConfig prompt. Restart the session — only `SessionStart` cold-starts the game.
- **Game crashes immediately with a dialog.** Port `1604` is in use (fixed, no discovery). Kill the conflicting process; check `netstat -ano | findstr :1604` (Windows) or `lsof -i :1604` (mac/Linux).
- **NPC stuck in wrong state.** Hook event missed or out of order. Next event self-corrects via the idempotent dispatcher; no manual fix.
- **Clicking NPC focuses the wrong window.** `hostPid` resolution failed. Linux needs `xdotool`; macOS uses `osascript`; Windows uses `Win32_Process`. Install missing tool and restart the session.
- **Manually closed game keeps relaunching.** Only `SessionStart` may launch. If it does relaunch on other events, a hook is misclassified — inspect `hooks/hooks.json`.
