#!/bin/bash

################################################################################
# sync.sh - Sync vibe-config settings
#
# Syncs:
#   - claude/ -> ~/.claude/
#   - kiro/   -> ~/.kiro/
#
# Usage:
#   ./sync.sh          # Sync all (default)
#   ./sync.sh -n       # Dry-run mode (show changes only)
#   ./sync.sh -h       # Show help
################################################################################

set -e

REPO_URL="https://github.com/nalbam/vibe-config.git"
SOURCE_DIR="${HOME}/.vibe-config"

SYNC_TARGETS=(
  "claude:${HOME}/.claude"
  "kiro:${HOME}/.kiro"
)

DRY_RUN=false

# Counters
COUNT_NEW=0
COUNT_UPDATED=0
COUNT_IDENTICAL=0

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}  ℹ $*${NC}"; }
log_ok()    { echo -e "${GREEN}  ✓ $*${NC}"; }
log_new()   { echo -e "${CYAN}  + $*${NC}"; }
log_warn()  { echo -e "${YELLOW}  ⚠ $*${NC}"; }

md5_hash() {
  if [[ "$(uname)" == "Darwin" ]]; then
    md5 -q "$1" 2>/dev/null
  else
    md5sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

is_binary() {
  file "$1" | grep -qv "text"
}

copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

show_diff() {
  local src="$1" dst="$2"

  if command -v colordiff >/dev/null 2>&1; then
    diff -u "$dst" "$src" | colordiff | head -30
  else
    diff -u "$dst" "$src" | head -30
  fi

  local total
  total=$(diff -u "$dst" "$src" | wc -l)
  if [[ $total -gt 30 ]]; then
    log_warn "... (${total} lines total, showing first 30)"
  fi
}

# Parse arguments
while getopts "nh" opt; do
  case $opt in
    n) DRY_RUN=true ;;
    h)
      echo "Usage: $0 [-n] [-h]"
      echo "  -n  Dry-run mode (show changes only)"
      echo "  -h  Show this help"
      exit 0
      ;;
    *)
      echo "Usage: $0 [-n] [-h]"
      exit 1
      ;;
  esac
done

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    VIBE-CONFIG SETTINGS SYNC                   ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

if [[ "$DRY_RUN" == true ]]; then
  log_warn "Dry-run mode: No files will be modified"
fi

# Clone or pull repository
echo -e "\n${CYAN}▶ Checking repository...${NC}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  log_info "Cloning: $REPO_URL"
  git clone "$REPO_URL" "$SOURCE_DIR"
  log_ok "Cloned successfully"
else
  log_info "Pulling: $SOURCE_DIR"
  git -C "$SOURCE_DIR" pull
  log_ok "Updated successfully"
fi

# Sync each target
for target_config in "${SYNC_TARGETS[@]}"; do
  src_subdir="${target_config%%:*}"
  dst_dir="${target_config#*:}"
  src_path="$SOURCE_DIR/$src_subdir"

  # Skip if source directory doesn't exist or is empty
  if [[ ! -d "$src_path" ]] || [[ -z "$(ls -A "$src_path" 2>/dev/null)" ]]; then
    log_info "Skipping $src_subdir/ (empty or not found)"
    continue
  fi

  echo -e "\n${CYAN}▶ Syncing $src_subdir/ -> $dst_dir/${NC}"

  # Create target directory if needed
  if [[ ! -d "$dst_dir" ]] && [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$dst_dir"
  fi

  # Find and process all files
  while IFS= read -r -d '' src_file; do
    rel_path="${src_file#$src_path/}"
    dst_file="$dst_dir/$rel_path"

    if [[ ! -f "$dst_file" ]]; then
      # New file
      log_new "NEW: $rel_path"
      if [[ "$DRY_RUN" == false ]]; then
        copy_file "$src_file" "$dst_file"
      fi
      COUNT_NEW=$((COUNT_NEW + 1))
    else
      # Existing file - compare
      src_md5=$(md5_hash "$src_file")
      dst_md5=$(md5_hash "$dst_file")

      if [[ "$src_md5" == "$dst_md5" ]]; then
        COUNT_IDENTICAL=$((COUNT_IDENTICAL + 1))
      else
        log_ok "UPDATE: $rel_path"
        if ! is_binary "$src_file"; then
          show_diff "$src_file" "$dst_file"
        fi
        if [[ "$DRY_RUN" == false ]]; then
          copy_file "$src_file" "$dst_file"
        fi
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
      fi
    fi
  done < <(find "$src_path" -type f -not -path '*/.git/*' -print0 | sort -z)
done

# Summary
echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                         SYNC COMPLETE                          ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo
log_info "Summary:"
log_new "  New files:     $COUNT_NEW"
log_ok "  Updated:       $COUNT_UPDATED"
log_info "  Already sync:  $COUNT_IDENTICAL"
echo
