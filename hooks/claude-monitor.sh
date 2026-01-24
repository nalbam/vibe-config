#!/bin/bash

# Claude Monitor Hook
# Desktop App (localhost:19280) + ESP32 (USB Serial / HTTP)

DEBUG="${DEBUG:-0}"
MODEL_CACHE_DIR="$HOME/.claude/.cache"

# ============================================================================
# Utility Functions
# ============================================================================

debug_log() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

capitalize() {
  local str="$1"
  echo "$(echo "${str:0:1}" | tr '[:lower:]' '[:upper:]')${str:1}"
}

# ============================================================================
# Input Parsing Functions
# ============================================================================

read_input() {
  timeout 5 cat 2>/dev/null || cat
}

parse_json_field() {
  local input="$1"
  local field="$2"
  local default="${3:-}"
  jq -r "$field // \"$default\"" <<< "$input" 2>/dev/null
}

# ============================================================================
# Model Functions
# ============================================================================

cache_model() {
  local model="$1"
  local session_id="$2"

  mkdir -p "$MODEL_CACHE_DIR" 2>/dev/null
  echo "$model" > "$MODEL_CACHE_DIR/model_current" 2>/dev/null
  if [ -n "$session_id" ]; then
    echo "$model" > "$MODEL_CACHE_DIR/model_$session_id" 2>/dev/null
  fi
}

get_cached_model() {
  local session_id="$1"

  if [ -n "$session_id" ] && [ -f "$MODEL_CACHE_DIR/model_$session_id" ]; then
    cat "$MODEL_CACHE_DIR/model_$session_id" 2>/dev/null
  elif [ -f "$MODEL_CACHE_DIR/model_current" ]; then
    cat "$MODEL_CACHE_DIR/model_current" 2>/dev/null
  fi
}

parse_model_name() {
  local model_raw="$1"

  [ -z "$model_raw" ] || [ "$model_raw" = "null" ] && return

  # Pattern: claude-{name}-{major}-{minor}-{date} or claude-{name}-{major}-{date}
  if [[ "$model_raw" =~ ^claude-([a-z]+)-([0-9]+)-([0-9]+)-[0-9]+$ ]]; then
    # claude-opus-4-5-20251101 -> Opus 4.5
    echo "$(capitalize "${BASH_REMATCH[1]}") ${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  elif [[ "$model_raw" =~ ^claude-([a-z]+)-([0-9]+)-[0-9]+$ ]]; then
    # claude-sonnet-4-20250514 -> Sonnet 4
    echo "$(capitalize "${BASH_REMATCH[1]}") ${BASH_REMATCH[2]}"
  elif [[ "$model_raw" =~ ^claude-([a-z]+) ]]; then
    # claude-sonnet -> Sonnet
    capitalize "${BASH_REMATCH[1]}"
  else
    echo "$model_raw"
  fi
}

# ============================================================================
# Memory Functions
# ============================================================================

get_memory_usage() {
  local context_used="$1"
  local context_total="$2"
  local transcript_path="$3"

  if [ "$context_total" -gt 0 ] 2>/dev/null; then
    echo "$((context_used * 100 / context_total))%"
  elif [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    local file_size
    file_size=$(stat -f%z "$transcript_path" 2>/dev/null || stat -c%s "$transcript_path" 2>/dev/null || echo 0)
    local file_kb=$((file_size / 1024))
    local memory_percent=$((file_kb / 100))
    [ "$memory_percent" -gt 99 ] && memory_percent=99
    [ "$memory_percent" -lt 1 ] && memory_percent=1
    echo "${memory_percent}%"
  fi
}

# ============================================================================
# State Functions
# ============================================================================

get_project_name() {
  local cwd="$1"
  local transcript_path="$2"

  if [ -n "$cwd" ]; then
    basename "$cwd"
  elif [ -n "$transcript_path" ]; then
    basename "$(dirname "$transcript_path")"
  fi
}

get_state() {
  local event_name="$1"

  case "$event_name" in
    "SessionStart") echo "session_start" ;;
    "PreToolUse"|"PostToolUse") echo "working" ;;
    "Stop") echo "tool_done" ;;
    "Notification") echo "notification" ;;
    *) echo "unknown" ;;
  esac
}

build_payload() {
  local state="$1"
  local event="$2"
  local tool="$3"
  local project="$4"
  local model="$5"
  local memory="$6"

  jq -n \
    --arg state "$state" \
    --arg event "$event" \
    --arg tool "$tool" \
    --arg project "$project" \
    --arg model "$model" \
    --arg memory "$memory" \
    '{state: $state, event: $event, tool: $tool, project: $project, model: $model, memory: $memory}'
}

# ============================================================================
# Send Functions
# ============================================================================

send_serial() {
  local port="$1"
  local data="$2"

  if [ -c "$port" ]; then
    stty -f "$port" 115200 2>/dev/null || stty -F "$port" 115200 2>/dev/null
    echo "$data" > "$port" 2>/dev/null
    return $?
  fi
  return 1
}

send_http() {
  local url="$1"
  local data="$2"

  curl -s -X POST "$url/status" \
    -H "Content-Type: application/json" \
    -d "$data" \
    --connect-timeout 2 \
    --max-time 5 \
    > /dev/null 2>&1
}

send_desktop() {
  local data="$1"

  curl -s -X POST "http://127.0.0.1:19280/status" \
    -H "Content-Type: application/json" \
    -d "$data" \
    --connect-timeout 1 \
    --max-time 2 \
    > /dev/null 2>&1
}

is_desktop_running() {
  curl -s "http://127.0.0.1:19280/health" \
    --connect-timeout 1 \
    --max-time 1 \
    > /dev/null 2>&1
}

show_desktop_window() {
  curl -s -X POST "http://127.0.0.1:19280/show" \
    --connect-timeout 1 \
    --max-time 1 \
    > /dev/null 2>&1
}

launch_desktop() {
  local app_dir="${CLAUDE_MONITOR_DESKTOP:-$HOME/workspace/github.com/nalbam/claude-monitor/desktop}"
  local start_script="$app_dir/start.sh"

  if [ -x "$start_script" ]; then
    debug_log "Launching Desktop App via start.sh: $start_script"
    "$start_script" > /dev/null 2>&1
    sleep 2
  else
    debug_log "Desktop App directory not found: $app_dir"
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  # Read input
  local input
  input=$(read_input)

  # Parse input fields
  local event_name tool_name cwd transcript_path session_id model_raw
  event_name=$(parse_json_field "$input" '.hook_event_name' 'Unknown')
  tool_name=$(parse_json_field "$input" '.tool_name' '')
  cwd=$(parse_json_field "$input" '.cwd' '')
  transcript_path=$(parse_json_field "$input" '.transcript_path' '')
  session_id=$(parse_json_field "$input" '.session_id' '')
  model_raw=$(parse_json_field "$input" '.model' '')

  # Handle model caching
  if [ -n "$model_raw" ] && [ "$model_raw" != "null" ]; then
    cache_model "$model_raw" "$session_id"
  else
    model_raw=$(get_cached_model "$session_id")
  fi

  # Parse model name and version
  local model_name
  model_name=$(parse_model_name "$model_raw")

  # Get memory usage
  local context_used context_total memory_usage
  context_used=$(parse_json_field "$input" '.context_window.used' '0')
  context_total=$(parse_json_field "$input" '.context_window.total' '0')
  memory_usage=$(get_memory_usage "$context_used" "$context_total" "$transcript_path")

  # Get project name and state
  local project_name state
  project_name=$(get_project_name "$cwd" "$transcript_path")
  state=$(get_state "$event_name")

  debug_log "Event: $event_name, Tool: $tool_name, Project: $project_name, Model: $model_name, Memory: $memory_usage"

  # Build payload
  local payload
  payload=$(build_payload "$state" "$event_name" "$tool_name" "$project_name" "$model_name" "$memory_usage")

  debug_log "Payload: $payload"

  # Send to Desktop App
  if [ -n "${CLAUDE_MONITOR_DESKTOP}" ]; then
    if [ "$event_name" = "SessionStart" ]; then
      if is_desktop_running; then
        debug_log "Desktop App running, showing window..."
        show_desktop_window
      else
        debug_log "Desktop App not running, launching..."
        launch_desktop
      fi
    fi
    send_desktop "$payload"
  fi

  # Send to ESP32 USB Serial
  if [ -n "${ESP32_SERIAL_PORT}" ]; then
    debug_log "Trying USB serial: ${ESP32_SERIAL_PORT}"
    if send_serial "${ESP32_SERIAL_PORT}" "$payload"; then
      debug_log "Sent via USB serial"
    else
      debug_log "USB serial failed"
    fi
  fi

  # Send to ESP32 HTTP
  if [ -n "${ESP32_HTTP_URL}" ]; then
    debug_log "Trying HTTP: ${ESP32_HTTP_URL}"
    if send_http "${ESP32_HTTP_URL}" "$payload"; then
      debug_log "Sent via HTTP"
    else
      debug_log "HTTP failed"
    fi
  fi
}

main
exit 0
