# vibe-config 프로젝트 컨텍스트 요약

> 생성일: 2026-02-05

## 프로젝트 개요

**vibe-config**는 Claude Code와 Kiro를 위한 AI 지원 개발 환경 설정을 관리하는 저장소입니다.

## 동기화 흐름

```
vibe-config/
├── claude/  ──sync──>  ~/.claude/
└── kiro/    ──sync──>  ~/.kiro/
```

## 핵심 구성요소

### 1. Claude Code 설정 (`claude/`)

| 파일/디렉토리 | 용도 |
|---------------|------|
| `CLAUDE.md` | 모든 프로젝트에 적용되는 글로벌 지침 |
| `settings.json` | 권한, 훅, 모델(opus), 플러그인 설정 |
| `statusline.py` | 토큰 사용량, 비용, 컨텍스트 표시 |
| `agents/` | 8개 전문 서브에이전트 |
| `hooks/` | VibeMon 상태 업데이트 |
| `rules/` | 7개 항상 적용 규칙 |
| `skills/` | 4개 사용자 호출 스킬 |

### 2. Kiro 설정 (`kiro/`)

| 파일/디렉토리 | 용도 |
|---------------|------|
| `agents/default.json` | 기본 에이전트 설정 |
| `hooks/vibemon.py` | VibeMon 상태 업데이트 |

## 에이전트 목록

| 에이전트 | 용도 |
|----------|------|
| `planner` | 구현 계획 수립 (Opus) |
| `architect` | 시스템 설계 및 아키텍처 |
| `builder` | 빌드, 린트, 타입체크 자동 수정 |
| `code-reviewer` | 코드 리뷰 (품질, 보안) |
| `test-writer` | 테스트 생성 |
| `refactorer` | 동작 변경 없이 리팩토링 |
| `doc-writer` | 문서 작성 |
| `debugger` | 디버깅 및 에러 해결 |

## 규칙 파일

| 규칙 | 내용 |
|------|------|
| `language.md` | 한국어 응답, 코드/커밋은 영어 |
| `coding-style.md` | 불변성, 파일 구조, 에러 처리 |
| `git-workflow.md` | 커밋 포맷, PR 프로세스, 명시적 허가 필요 |
| `patterns.md` | API 응답 형식, 공통 패턴 |
| `performance.md` | 모델 선택 전략 (Opus/Sonnet/Haiku) |
| `security.md` | 보안 체크리스트, 시크릿 관리 |
| `testing.md` | TDD 워크플로우, 80% 커버리지 |

## 스킬 목록

| 스킬 | 설명 |
|------|------|
| `/commit` | 컨벤셔널 포맷으로 커밋 생성 |
| `/pr-create` | PR 생성 (요약, 테스트 계획 포함) |
| `/validate` | 린트, 타입체크, 테스트 실행 및 자동 수정 |
| `/docs-sync` | 문서 분석 및 업데이트 |

## Vibe Monitor

실시간 상태 표시 시스템:

**대상:**
- Desktop App (Electron, macOS) - `localhost:19280`
- ESP32 디바이스 (USB Serial 또는 HTTP)

**상태:**
| 상태 | 트리거 | 설명 |
|------|--------|------|
| `start` | SessionStart | 세션 초기화 |
| `thinking` | UserPromptSubmit | 사용자 입력 처리 중 |
| `planning` | UserPromptSubmit (plan mode) | 계획 모드 활성 |
| `working` | PreToolUse | 도구 실행 중 |
| `done` | Stop | 작업 완료 |
| `notification` | Notification | 사용자 입력 대기 |

## 훅 이벤트

| 이벤트 | 스크립트 | 용도 |
|--------|----------|------|
| SessionStart | vibemon.py | 상태 초기화 |
| UserPromptSubmit | vibemon.py | thinking 상태 |
| PreToolUse | vibemon.py | working 상태 |
| Stop | vibemon.py | done 상태 |
| Notification | vibemon.py | 알림 상태 |

## 사용법

```bash
# 전체 동기화
./sync.sh

# 드라이런 (변경사항만 확인)
./sync.sh -n

# 원격에서 설치
bash -c "$(curl -fsSL nalbam.github.io/vibe-config/sync.sh)"
```

## 환경 변수 (`~/.claude/.env.local`)

```bash
VIBEMON_CACHE_PATH=~/.claude/statusline-cache.json
VIBEMON_AUTO_LAUNCH=0
VIBEMON_HTTP_URLS=http://127.0.0.1:19280
VIBEMON_SERIAL_PORT=/dev/cu.usbmodem*
```

## 관련 프로젝트

- [vibemon](https://github.com/nalbam/vibemon) - Desktop App 및 ESP32 펌웨어
- [dotfiles](https://github.com/nalbam/dotfiles) - 개발 환경 설정
