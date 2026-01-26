#!/bin/bash

# Claude Code Statusline Hook
# Displays status line and sends context usage to VibeMon

# ============================================================================
# Environment Loading
# ============================================================================

load_env() {
  local env_file="$HOME/.claude/.env.local"

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
# VibeMon Cache Functions
# ============================================================================

VIBE_MONITOR_CACHE="${VIBE_MONITOR_CACHE:-$HOME/.claude/.vibe-monitor.json}"
VIBE_MONITOR_MAX_PROJECTS=10

save_to_cache() {
  local project="$1"
  local model="$2"
  local memory="$3"
  local timestamp
  timestamp=$(date +%s)

  # Only save if project is set
  [ -z "$project" ] && return

  # Read existing cache or create empty object
  local cache="{}"
  if [ -f "$VIBE_MONITOR_CACHE" ]; then
    cache=$(cat "$VIBE_MONITOR_CACHE" 2>/dev/null || echo "{}")
  fi

  # Update cache with new project data (with timestamp)
  # Then keep only the most recent N projects
  cache=$(echo "$cache" | jq \
    --arg project "$project" \
    --arg model "$model" \
    --arg memory "$memory" \
    --argjson ts "$timestamp" \
    --argjson max "$VIBE_MONITOR_MAX_PROJECTS" \
    '.[$project] = {model: $model, memory: $memory, ts: $ts} |
     to_entries | sort_by(.value.ts) | reverse | .[:$max] | from_entries' 2>/dev/null)

  # Write back to cache file
  echo "$cache" > "$VIBE_MONITOR_CACHE" 2>/dev/null
}

# ============================================================================
# ANSI Colors
# ============================================================================

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_MAGENTA='\033[35m'
C_BLUE='\033[34m'
C_ORANGE='\033[38;5;208m'

# ============================================================================
# Formatting Functions
# ============================================================================

format_number() {
  local num="$1"

  # Handle empty or invalid input
  if [ -z "$num" ] || [ "$num" = "null" ] || [ "$num" = "0" ]; then
    echo "0"
    return
  fi

  # Remove decimal part for comparison
  local int_num="${num%.*}"

  if [ "$int_num" -ge 1000000 ]; then
    # Use awk instead of bc for better portability
    awk "BEGIN {printf \"%.1fM\", $num / 1000000}"
  elif [ "$int_num" -ge 1000 ]; then
    awk "BEGIN {printf \"%.1fK\", $num / 1000}"
  else
    echo "$int_num"
  fi
}

format_duration() {
  local ms="$1"

  # Handle empty or invalid input
  if [ -z "$ms" ] || [ "$ms" = "null" ] || [ "$ms" = "0" ]; then
    echo "0s"
    return
  fi

  local total_seconds=$((ms / 1000))
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  if [ "$hours" -gt 0 ]; then
    printf "%dh%dm" "$hours" "$minutes"
  elif [ "$minutes" -gt 0 ]; then
    printf "%dm%ds" "$minutes" "$seconds"
  else
    printf "%ds" "$seconds"
  fi
}

format_cost() {
  local cost="$1"

  # Handle empty or invalid input
  if [ -z "$cost" ] || [ "$cost" = "null" ]; then
    echo "\$0.00"
    return
  fi

  printf "\$%.2f" "$cost"
}

# ============================================================================
# Progress Bar Functions
# ============================================================================

build_progress_bar() {
  local percent="$1"
  local width="${2:-10}"

  # Remove % sign if present
  percent="${percent%\%}"

  # Handle empty or invalid input
  if [ -z "$percent" ] || ! [[ "$percent" =~ ^[0-9]+$ ]]; then
    echo ""
    return
  fi

  local filled=$((percent * width / 100))
  local empty=$((width - filled))

  # Color based on usage level
  local color="$C_GREEN"
  if [ "$percent" -ge 90 ]; then
    color="$C_RED"
  elif [ "$percent" -ge 75 ]; then
    color="$C_YELLOW"
  fi

  # Build the bar - filled in color, empty in gray
  local bar=""
  for ((i=0; i<filled; i++)); do
    bar="${bar}━"
  done

  local empty_bar=""
  for ((i=0; i<empty; i++)); do
    empty_bar="${empty_bar}╌"
  done

  printf "%b%s%b%b%s%b %s%%" "$color" "$bar" "$C_RESET" "$C_DIM" "$empty_bar" "$C_RESET" "$percent"
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
  local input_tokens="$6"
  local output_tokens="$7"
  local cost="$8"
  local duration="$9"
  local lines_added="${10}"
  local lines_removed="${11}"

  local SEP=" │ "
  local status_line=""

  # # Kubernetes context (☸ icon)
  # if [ -n "$kube_info" ]; then
  #   # Remove surrounding parentheses and space
  #   kube_info="${kube_info#(}"
  #   kube_info="${kube_info%) }"
  #   status_line="${C_CYAN}☸ ${kube_info}${C_RESET}${SEP}"
  # fi

  # Directory (📂 icon)
  status_line="${status_line}${C_BLUE}📂 ${dir_name}${C_RESET}"

  # Git info (🌿 icon)
  if [ -n "$git_info" ]; then
    # Extract branch and status from " git:(branch *)" format
    local branch_info="${git_info#* git:(}"
    branch_info="${branch_info%)}"
    status_line="${status_line}${SEP}${C_GREEN}🌿 ${branch_info}${C_RESET}"
  fi

  # Model (🤖 icon) - remove "Claude " prefix, keep version
  local short_model="${model#Claude }"
  status_line="${status_line}${SEP}${C_MAGENTA}🤖 ${short_model}${C_RESET}"

  # Token usage (📥 in / 📤 out)
  if [ -n "$input_tokens" ] && [ "$input_tokens" != "0" ]; then
    local in_fmt out_fmt
    in_fmt=$(format_number "$input_tokens")
    out_fmt=$(format_number "$output_tokens")
    status_line="${status_line}${SEP}${C_CYAN}📥 ${in_fmt} 📤 ${out_fmt}${C_RESET}"
  fi

  # Cost (💰 icon)
  if [ -n "$cost" ] && [ "$cost" != "0" ] && [ "$cost" != "null" ]; then
    local cost_fmt
    cost_fmt=$(format_cost "$cost")
    status_line="${status_line}${SEP}${C_YELLOW}💰 ${cost_fmt}${C_RESET}"
  fi

  # Duration (⏱️ icon)
  if [ -n "$duration" ] && [ "$duration" != "0" ] && [ "$duration" != "null" ]; then
    local duration_fmt
    duration_fmt=$(format_duration "$duration")
    status_line="${status_line}${SEP}${C_DIM}⏱️ ${duration_fmt}${C_RESET}"
  fi

  # Lines changed (+/-)
  if [ -n "$lines_added" ] && [ "$lines_added" != "0" ]; then
    status_line="${status_line}${SEP}${C_GREEN}+${lines_added}${C_RESET}"
    if [ -n "$lines_removed" ] && [ "$lines_removed" != "0" ]; then
      status_line="${status_line} ${C_RED}-${lines_removed}${C_RESET}"
    fi
  fi

  # Context usage with progress bar (🧠 icon)
  if [ -n "$context_usage" ]; then
    local progress_bar
    progress_bar=$(build_progress_bar "$context_usage")
    if [ -n "$progress_bar" ]; then
      status_line="${status_line}${SEP}🧠 ${progress_bar}"
    fi
  fi

  printf "%b" "$status_line"
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

  # Parse token usage
  local input_tokens output_tokens
  input_tokens=$(parse_json_field "$input" '.context_window.total_input_tokens' '0')
  output_tokens=$(parse_json_field "$input" '.context_window.total_output_tokens' '0')

  # Parse cost info
  local cost duration lines_added lines_removed
  cost=$(parse_json_field "$input" '.cost.total_cost_usd' '0')
  duration=$(parse_json_field "$input" '.cost.total_duration_ms' '0')
  lines_added=$(parse_json_field "$input" '.cost.total_lines_added' '0')
  lines_removed=$(parse_json_field "$input" '.cost.total_lines_removed' '0')

  # Save project metadata to cache (vibe-monitor.sh will read this)
  save_to_cache "$dir_name" "$model_display" "$context_usage" &

  # Output statusline
  build_statusline "$model_display" "$dir_name" "$git_info" "$kube_info" "$context_usage" \
    "$input_tokens" "$output_tokens" "$cost" "$duration" "$lines_added" "$lines_removed"
}

main
