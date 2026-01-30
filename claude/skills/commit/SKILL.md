---
name: commit
description: Create git commit with conventional format. 커밋 생성, 변경사항 분석, 커밋 메시지 작성.
allowed-tools: Read, Bash, Grep, Glob
---

# Create Commit

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

## Workflow

### 0. Run Validation First
Before committing, run `/validate` to ensure all checks pass:
- Lint
- Typecheck
- Tests

**If validation fails, fix all issues before proceeding.**

### 1. Analyze Changes
```bash
# Check current status (never use -uall flag)
git status

# View staged and unstaged changes
git diff
git diff --cached

# View recent commits for message style reference
git log --oneline -10
```

### 2. Review Changes
Before committing:
- [ ] No secrets (API keys, passwords, tokens)
- [ ] No debug code (console.log, print statements)
- [ ] No unintended files (.env, node_modules, etc.)
- [ ] Changes are related and focused

### 3. Stage Files
```bash
# Stage specific files (preferred)
git add path/to/file1 path/to/file2

# Or stage all changes (use with caution)
git add -A
```

**Avoid staging:**
- `.env`, `credentials.json`, secrets
- Large binaries or generated files
- Unrelated changes

### 4. Create Commit
```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

<optional body explaining why>
EOF
)"
```

### 5. Verify Commit
```bash
git status
git log --oneline -3
```

## Commit Message Format

```
<type>: <subject>

<optional body>
```

**Types:**
| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code refactoring (no behavior change) |
| `test` | Adding or updating tests |
| `chore` | Maintenance, dependencies |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |

**Subject Rules:**
- Use imperative mood: "Add feature" not "Added feature"
- No period at the end
- Max 50 characters
- Focus on "what" and "why", not "how"

**Examples:**
```
feat: add user authentication with OAuth2
fix: handle null response from payment API
refactor: simplify date formatting logic
docs: update API documentation for v2 endpoints
test: add unit tests for user service
chore: update dependencies to latest versions
```

## Pre-Commit Checklist

- [ ] All tests pass
- [ ] Lint checks pass
- [ ] No sensitive data exposed
- [ ] Commit is atomic (single purpose)
- [ ] Message clearly describes changes

## Rules

- Only include actual work done in the message
- Do NOT add unnecessary lines (Co-Authored-By, Generated with, etc.)
- Do NOT add promotional or attribution footers

## Anti-Patterns

- Do NOT commit multiple unrelated changes together
- Do NOT use vague messages like "fix", "update", "WIP"
- Do NOT commit secrets or credentials
- Do NOT skip pre-commit hooks (--no-verify)
- Do NOT amend commits already pushed to shared branches
