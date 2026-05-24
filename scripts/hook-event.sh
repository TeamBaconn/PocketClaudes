#!/bin/sh
# Hook entry point for macOS / Linux. Reads Claude Code hook JSON from stdin,
# builds a flat IpcCommand, and delivers it to the running PocketClaudes game.
# On Windows (Git Bash / MSYS), exits immediately so the PowerShell fallback runs.

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) exit 1 ;;
esac

GAME_PORT=1604

raw=$(cat)
[ -z "$raw" ] && exit 0

# Parse fields from the hook JSON. Uses lightweight grep/sed — no jq dependency.
json_field() {
  printf '%s' "$raw" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

event_name=$(json_field hook_event_name)
session_id=$(json_field session_id)
agent_id=$(json_field agent_id)
agent_type=$(json_field agent_type)
tool_name=$(json_field tool_name)
tool_use_id=$(json_field tool_use_id)
model=$(json_field model)
cwd=$(json_field cwd)

# Walk the parent-process chain to find the terminal/IDE window.
get_host_pid() {
  pid=$$
  i=0
  while [ "$i" -lt 12 ]; do
    if [ "$(uname -s)" = "Darwin" ]; then
      parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    else
      parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    fi
    [ -z "$parent" ] || [ "$parent" -le 1 ] 2>/dev/null && break

    if [ "$(uname -s)" = "Darwin" ]; then
      # Check if the process has a window via lsappinfo / AppleScript.
      wcount=$(osascript -e "tell application \"System Events\" to get (count of windows of (first process whose unix id is $parent))" 2>/dev/null)
      if [ "$wcount" -gt 0 ] 2>/dev/null; then
        echo "$parent"
        return
      fi
    else
      # Linux: check via xdotool if available.
      if command -v xdotool >/dev/null 2>&1; then
        wid=$(xdotool search --pid "$parent" 2>/dev/null | head -1)
        if [ -n "$wid" ]; then
          echo "$parent"
          return
        fi
      fi
    fi

    pid=$parent
    i=$((i + 1))
  done
  echo 0
}

host_pid=$(get_host_pid)

# Build the IpcCommand JSON payload.
json=$(cat <<EOF
{"v":1,"eventName":"${event_name}","sessionId":"${session_id}","agentId":"${agent_id}","agentType":"${agent_type}","toolName":"${tool_name}","toolUseId":"${tool_use_id}","model":"${model}","hostPid":${host_pid},"cwd":"${cwd}"}
EOF
)

# Resolve game executable for cold start (SessionStart only).
game_exe=""
if [ "$event_name" = "SessionStart" ]; then
  game_exe="${CLAUDE_PLUGIN_OPTION_GAME_EXE:-$POCKETCLAUDES_EXE}"
fi

# Try HTTP POST first.
posted=false
if command -v curl >/dev/null 2>&1; then
  if curl -s -f -X POST "http://127.0.0.1:${GAME_PORT}/" \
       -H 'Content-Type: application/json' \
       -d "$json" \
       --connect-timeout 2 \
       -o /dev/null 2>/dev/null; then
    posted=true
  fi
fi

# Cold-start fallback.
if [ "$posted" = false ]; then
  if [ -n "$game_exe" ] && [ -x "$game_exe" ]; then
    nohup "$game_exe" --event "$json" >/dev/null 2>&1 &
  fi
fi

exit 0
