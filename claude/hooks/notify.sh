#!/bin/bash

# Claude Code Notification Hook
# Supports: macOS, WSL, ntfy.sh, Slack

# ============================================================================
# Environment Loading
# ============================================================================

# Load environment from .env.local (if not already set in shell profile)
# Priority: Shell environment > .env.local file
load_env() {
  local env_file=""

  # Determine env file path based on script location
  local script_path="${BASH_SOURCE[0]}"
  if [[ "$script_path" == *".kiro"* ]]; then
    env_file="$HOME/.kiro/.env.local"
  else
    env_file="$HOME/.claude/.env.local"
  fi

  # Source if file exists and variables not already set
  if [ -f "$env_file" ]; then
    # shellcheck source=/dev/null
    source "$env_file"
  fi
}

load_env

DEBUG="${DEBUG:-0}"

# ============================================================================
# Utility Functions
# ============================================================================

debug_log() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# ============================================================================
# Input Parsing Functions
# ============================================================================

read_input() {
  local input
  read -t 10 input
  echo "$input"
}

parse_json_field() {
  local input="$1"
  local field="$2"
  local default="${3:-}"
  echo "$input" | jq -r "$field // \"$default\"" 2>/dev/null
}

get_project_name() {
  local cwd="$1"
  local transcript_path="$2"

  if [ -n "$cwd" ]; then
    basename "$cwd"
  elif [ -n "$transcript_path" ]; then
    basename "$(dirname "$transcript_path")"
  fi
}

# ============================================================================
# Message Functions
# ============================================================================

build_message() {
  local event_name="$1"
  local project_name="$2"
  local msg_type="$3"  # title, message, slack

  case "$event_name" in
    "Stop")
      case "$msg_type" in
        title) echo "Claude Code" ;;
        message)
          if [ -n "$project_name" ]; then
            echo "[$project_name] 작업 완료"
          else
            echo "작업 완료"
          fi
          ;;
        slack)
          if [ -n "$project_name" ]; then
            echo ":white_check_mark: Claude Code [$project_name] 작업 완료"
          else
            echo ":white_check_mark: Claude Code 작업 완료"
          fi
          ;;
      esac
      ;;
    "Notification")
      case "$msg_type" in
        title) echo "Claude Code" ;;
        message)
          if [ -n "$project_name" ]; then
            echo "[$project_name] 입력을 기다리고 있습니다"
          else
            echo "입력을 기다리고 있습니다"
          fi
          ;;
        slack)
          if [ -n "$project_name" ]; then
            echo ":question: Claude Code [$project_name] 입력을 기다리고 있습니다"
          else
            echo ":question: Claude Code가 입력을 기다리고 있습니다"
          fi
          ;;
      esac
      ;;
    *)
      case "$msg_type" in
        title) echo "Claude Code" ;;
        message) echo "$event_name" ;;
        slack) echo ":bell: Claude Code: $event_name" ;;
      esac
      ;;
  esac
}

get_sound_file() {
  local event_name="$1"

  case "$event_name" in
    "Stop") echo ~/.claude/sounds/ding1.mp3 ;;
    "Notification") echo ~/.claude/sounds/ding2.mp3 ;;
    *) echo ~/.claude/sounds/ding3.mp3 ;;
  esac
}

# ============================================================================
# Notification Functions
# ============================================================================

notify_macos() {
  local title="$1"
  local message="$2"

  [[ "$NOTIFY_SYSTEM" != "1" ]] && {
    debug_log "macOS notification disabled (NOTIFY_SYSTEM=0)"
    return
  }

  debug_log "Sending macOS notification: $message"
  if osascript -e "display notification \"$message\" with title \"$title\"" 2>&1 | grep -v "^$" >&2; then
    debug_log "macOS notification sent successfully"
  fi
}

play_sound_macos() {
  local sound_file="$1"

  [[ "$NOTIFY_SOUND" != "1" ]] && {
    debug_log "Sound notification disabled (NOTIFY_SOUND=0)"
    return
  }

  if [ -f "$sound_file" ]; then
    debug_log "Playing sound: $sound_file"
    if [[ "$DEBUG" == "1" ]]; then
      afplay "$sound_file" 2>&1 | grep -v "^$" >&2
    else
      nohup afplay "$sound_file" >/dev/null 2>&1 &
    fi
  else
    debug_log "Sound file not found: $sound_file"
  fi
}

notify_wsl() {
  debug_log "WSL detected, sending beep notification"

  if ! command -v powershell.exe &> /dev/null; then
    debug_log "powershell.exe not found"
    return
  fi

  if [[ "$DEBUG" == "1" ]]; then
    powershell.exe -Command "[console]::beep(800, 300)" 2>&1 | grep -v "^$" >&2
  else
    powershell.exe -Command "[console]::beep(800, 300)" 2>/dev/null &
  fi
  debug_log "WSL beep sent"
}

notify_ntfy() {
  local title="$1"
  local message="$2"
  local topic="${NTFY_TOPIC}"

  [ -z "$topic" ] && return

  debug_log "Sending ntfy.sh notification to topic: $topic"
  if [[ "$DEBUG" == "1" ]]; then
    curl -X POST "https://ntfy.sh/${topic}" \
      -H "Title: ${title}" \
      -H "Tags: robot" \
      -d "${message}" 2>&1 | head -3 >&2
  else
    curl -s -X POST "https://ntfy.sh/${topic}" \
      -H "Title: ${title}" \
      -H "Tags: robot" \
      -d "${message}" > /dev/null 2>&1
  fi
  debug_log "ntfy.sh notification sent"
}

notify_slack() {
  local message="$1"
  local webhook_url="${SLACK_WEBHOOK_URL}"

  [ -z "$webhook_url" ] && return

  debug_log "Sending Slack notification"
  if [[ "$DEBUG" == "1" ]]; then
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$message\"}" \
      "$webhook_url" 2>&1 | head -3 >&2
  else
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$message\"}" \
      "$webhook_url" > /dev/null 2>&1
  fi
  debug_log "Slack notification sent"
}

# ============================================================================
# Platform Detection
# ============================================================================

is_macos() {
  [[ "$OSTYPE" == "darwin"* ]]
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

# ============================================================================
# Main
# ============================================================================

main() {
  # Read and parse input
  local input
  input=$(read_input)

  local event_name cwd transcript_path project_name
  event_name=$(parse_json_field "$input" '.hook_event_name' 'Unknown')
  cwd=$(parse_json_field "$input" '.cwd' '')
  transcript_path=$(parse_json_field "$input" '.transcript_path' '')
  project_name=$(get_project_name "$cwd" "$transcript_path")

  debug_log "Event: $event_name, Project: $project_name"

  # Build messages
  local title message slack_message
  title=$(build_message "$event_name" "$project_name" "title")
  message=$(build_message "$event_name" "$project_name" "message")
  slack_message=$(build_message "$event_name" "$project_name" "slack")

  # Send notifications based on platform
  if is_macos; then
    notify_macos "$title" "$message"
    play_sound_macos "$(get_sound_file "$event_name")"
  fi

  if is_wsl; then
    notify_wsl
  fi

  # External notifications
  notify_ntfy "$title" "$message"
  notify_slack "$slack_message"
}

main
exit 0
