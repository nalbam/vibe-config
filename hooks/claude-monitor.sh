#!/bin/bash

# Claude Monitor Hook
# Desktop App (localhost:19280) + ESP32 (USB Serial / HTTP)

DEBUG="${DEBUG:-0}"

debug_log() {
  if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# 입력 읽기 (timeout으로 전체 stdin 읽기)
input=$(timeout 5 cat 2>/dev/null || cat)

# 이벤트 정보 추출 (here-string 사용으로 큰 JSON 안정적 처리)
event_name=$(jq -r '.hook_event_name // "Unknown"' <<< "$input" 2>/dev/null)
tool_name=$(jq -r '.tool_name // ""' <<< "$input" 2>/dev/null)
cwd=$(jq -r '.cwd // ""' <<< "$input" 2>/dev/null)
transcript_path=$(jq -r '.transcript_path // ""' <<< "$input" 2>/dev/null)

# jq 실패 시 기본값
[ -z "$event_name" ] && event_name="Unknown"

# 프로젝트 이름 추출 (cwd > transcript_path)
if [ -n "$cwd" ]; then
  project_name=$(basename "$cwd")
elif [ -n "$transcript_path" ]; then
  # transcript_path: ~/.claude/projects/project-name/session.jsonl
  project_name=$(basename "$(dirname "$transcript_path")")
else
  project_name=""
fi

debug_log "Event: $event_name, Tool: $tool_name, Project: $project_name"

# 상태 결정
case "$event_name" in
  "SessionStart")
    state="session_start"
    ;;
  "PreToolUse")
    state="working"
    ;;
  "PostToolUse")
    state="working"
    ;;
  "Stop")
    state="idle"
    ;;
  "Notification")
    state="notification"
    ;;
  *)
    state="unknown"
    ;;
esac

# JSON 페이로드 생성
payload=$(jq -n \
  --arg state "$state" \
  --arg event "$event_name" \
  --arg tool "$tool_name" \
  --arg project "$project_name" \
  '{state: $state, event: $event, tool: $tool, project: $project}')

debug_log "Payload: $payload"

# 전송 함수: USB 시리얼
send_serial() {
  local port="$1"
  local data="$2"

  if [ -c "$port" ]; then
    # 시리얼 포트 설정 (115200 baud)
    stty -f "$port" 115200 2>/dev/null || stty -F "$port" 115200 2>/dev/null
    echo "$data" > "$port" 2>/dev/null
    return $?
  fi
  return 1
}

# 전송 함수: HTTP
send_http() {
  local url="$1"
  local data="$2"

  curl -s -X POST "$url/status" \
    -H "Content-Type: application/json" \
    -d "$data" \
    --connect-timeout 2 \
    --max-time 5 \
    > /dev/null 2>&1
  return $?
}

# 전송 함수: Desktop App (localhost:19280)
send_desktop() {
  local data="$1"

  curl -s -X POST "http://127.0.0.1:19280/status" \
    -H "Content-Type: application/json" \
    -d "$data" \
    --connect-timeout 1 \
    --max-time 2 \
    > /dev/null 2>&1
  return $?
}

# 전송 시도
sent=false

# 0. Desktop App 시도 (항상 시도, 실패해도 계속)
send_desktop "$payload"

# 1. USB 시리얼 시도
if [ -n "${ESP32_SERIAL_PORT}" ]; then
  debug_log "Trying USB serial: ${ESP32_SERIAL_PORT}"
  if send_serial "${ESP32_SERIAL_PORT}" "$payload"; then
    debug_log "Sent via USB serial"
    sent=true
  else
    debug_log "USB serial failed"
  fi
fi

# 2. HTTP fallback
if [ "$sent" = false ] && [ -n "${ESP32_HTTP_URL}" ]; then
  debug_log "Trying HTTP: ${ESP32_HTTP_URL}"
  if send_http "${ESP32_HTTP_URL}" "$payload"; then
    debug_log "Sent via HTTP"
    sent=true
  else
    debug_log "HTTP failed"
  fi
fi

# 3. 자동 감지 (설정 없을 때)
if [ "$sent" = false ] && [ -z "${ESP32_SERIAL_PORT}" ] && [ -z "${ESP32_HTTP_URL}" ]; then
  # macOS USB 시리얼 자동 감지
  for port in /dev/cu.usbserial-* /dev/cu.usbmodem* /dev/cu.wchusbserial*; do
    if [ -c "$port" ]; then
      debug_log "Auto-detected serial port: $port"
      if send_serial "$port" "$payload"; then
        debug_log "Sent via auto-detected serial"
        sent=true
        break
      fi
    fi
  done
fi

if [ "$sent" = false ]; then
  debug_log "No ESP32 connection available"
fi

exit 0
