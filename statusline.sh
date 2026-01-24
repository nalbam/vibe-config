#!/bin/bash

# Claude Code Statusline Hook
# Displays status line and sends context usage to Desktop App

# ============================================================================
# Utility Functions
# ============================================================================

read_input() {
  cat
}

parse_json_field() {
  local input="$1"
  local field="$2"
  local default="${3:-}"
  echo "$input" | jq -r "$field // \"$default\"" 2>/dev/null
}

# ============================================================================
# Git Functions
# ============================================================================

get_git_info() {
  local dir="$1"
  local git_info=""

  if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
    local branch
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
      if ! git -C "$dir" diff-index --quiet HEAD -- 2>/dev/null; then
        git_info=" git:($branch *)"
      else
        git_info=" git:($branch)"
      fi
    fi
  fi

  echo "$git_info"
}

# ============================================================================
# Kubernetes Functions
# ============================================================================

get_kube_info() {
  local kube_info=""

  if command -v kubectl > /dev/null 2>&1; then
    local context namespace
    context=$(kubectl config current-context 2>/dev/null)
    if [ -n "$context" ]; then
      namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
      if [ -n "$namespace" ] && [ "$namespace" != "default" ]; then
        kube_info="($context:$namespace) "
      else
        kube_info="($context) "
      fi
    fi
  fi

  echo "$kube_info"
}

# ============================================================================
# Context Window Functions
# ============================================================================

get_context_usage() {
  local input="$1"

  # Try pre-calculated percentage first
  local used_pct
  used_pct=$(parse_json_field "$input" '.context_window.used_percentage' '0')

  if [ -n "$used_pct" ] && [ "$used_pct" != "null" ] && [ "$used_pct" != "0" ]; then
    printf "%.0f%%" "$used_pct"
    return
  fi

  # Fallback: calculate from current_usage
  local context_size current_tokens
  context_size=$(parse_json_field "$input" '.context_window.context_window_size' '0')

  if [ "$context_size" -gt 0 ] 2>/dev/null; then
    local input_tokens cache_creation cache_read
    input_tokens=$(parse_json_field "$input" '.context_window.current_usage.input_tokens' '0')
    cache_creation=$(parse_json_field "$input" '.context_window.current_usage.cache_creation_input_tokens' '0')
    cache_read=$(parse_json_field "$input" '.context_window.current_usage.cache_read_input_tokens' '0')

    current_tokens=$((input_tokens + cache_creation + cache_read))
    if [ "$current_tokens" -gt 0 ]; then
      echo "$((current_tokens * 100 / context_size))%"
      return
    fi
  fi

  echo ""
}

# ============================================================================
# Desktop App Functions
# ============================================================================

is_desktop_running() {
  curl -s "http://127.0.0.1:19280/health" \
    --connect-timeout 1 \
    --max-time 1 \
    > /dev/null 2>&1
}

send_to_desktop() {
  local project="$1"
  local model="$2"
  local memory="$3"

  # Only send if CLAUDE_MONITOR_DESKTOP is set and app is running
  [ -z "${CLAUDE_MONITOR_DESKTOP}" ] && return
  [ -z "$project" ] && return
  is_desktop_running || return

  # Build JSON payload with project for session matching
  local payload="{\"project\":\"$project\""

  if [ -n "$model" ]; then
    payload="${payload},\"model\":\"$model\""
  fi

  if [ -n "$memory" ]; then
    payload="${payload},\"memory\":\"$memory\""
  fi

  payload="${payload}}"

  curl -s -X POST "http://127.0.0.1:19280/status" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --connect-timeout 1 \
    --max-time 2 \
    > /dev/null 2>&1
}

# ============================================================================
# Statusline Output
# ============================================================================

build_statusline() {
  local model="$1"
  local dir_name="$2"
  local git_info="$3"
  local kube_info="$4"
  local context_usage="$5"

  local status_line=""

  # Kubernetes context
  if [ -n "$kube_info" ]; then
    status_line="${kube_info}"
  fi

  # Directory and git info
  status_line="${status_line}${dir_name}${git_info}"

  # Model
  status_line="${status_line} [${model}]"

  # Context usage
  if [ -n "$context_usage" ]; then
    status_line="${status_line} ${context_usage}"
  fi

  printf "%s" "$status_line"
}

# ============================================================================
# Main
# ============================================================================

main() {
  local input
  input=$(read_input)

  # Parse input fields
  local model_display current_dir
  model_display=$(parse_json_field "$input" '.model.display_name' 'Claude')
  current_dir=$(parse_json_field "$input" '.workspace.current_dir' '')

  local dir_name
  dir_name=$(basename "$current_dir")

  # Get additional info
  local git_info kube_info context_usage
  git_info=$(get_git_info "$current_dir")
  kube_info=$(get_kube_info)
  context_usage=$(get_context_usage "$input")

  # Send project, model and context usage to Desktop App (if running)
  send_to_desktop "$dir_name" "$model_display" "$context_usage" &

  # Output statusline
  build_statusline "$model_display" "$dir_name" "$git_info" "$kube_info" "$context_usage"
}

main
