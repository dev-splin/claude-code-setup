# using-skill

Claude Code에서 사용하는 커스텀 스킬 및 에이전트 아카이빙 프로젝트

## 디렉토리 구조

```
using-skill/
├── commit/
│   └── SKILL.md
├── figma-to-jira/
│   ├── SKILL.md
│   └── agents/
│       ├── figma-analyzer/
│       │   └── AGENT.md
│       └── jira-creator/
│           └── AGENT.md
└── dev-process/
    ├── SKILL.md
    └── agents/
        └── dev-process-planner/
            └── AGENT.md
```

## 커스텀 스킬

| 스킬 | 설명 | 사용 에이전트 |
|------|------|-------------|
| [commit](./commit/SKILL.md) | 프로젝트 커밋 컨벤션에 맞춰 변경사항을 스테이징하고 커밋 | - |
| [figma-to-jira](./figma-to-jira/SKILL.md) | Figma 디자인 페이지를 분석하여 Jira 서브태스크 자동 생성 | figma-analyzer, jira-creator |
| [dev-process](./dev-process/SKILL.md) | 체계적 18단계 개발 프로세스 (계획 → 구현 → 검토 → 커밋) | dev-process-planner |

## 커스텀 에이전트

| 에이전트 | 모델 | 설명 | 소속 스킬 |
|---------|------|------|----------|
| [figma-analyzer](./figma-to-jira/agents/figma-analyzer/AGENT.md) | Opus | Figma 디자인 분석 및 구현 태스크 분해 | figma-to-jira |
| [jira-creator](./figma-to-jira/agents/jira-creator/AGENT.md) | Sonnet | 분석된 태스크를 Jira 서브태스크로 생성 | figma-to-jira |
| [dev-process-planner](./dev-process/agents/dev-process-planner/AGENT.md) | Opus | dev-process 스킬의 1단계 계획 수립 | dev-process |

## 마켓플레이스 스킬

에이전트에서 참조하는 외부 스킬 목록입니다.

| 스킬 | 설명 | 소스 |
|------|------|------|
| planning-with-files | Manus 스타일 파일 기반 계획 수립 (task_plan.md, findings.md, progress.md 생성) | https://github.com/othmanadi/planning-with-files |
| next-best-practices | Next.js 파일 컨벤션, RSC, 데이터 패턴, 메타데이터, 에러 핸들링 등 베스트 프랙티스 | https://github.com/vercel-labs/next-skills |
| vercel-react-best-practices | Vercel 엔지니어링 기반 React/Next.js 성능 최적화 가이드라인 | https://github.com/vercel-labs/agent-skills |
| skill-creator | 새 스킬 생성, 기존 스킬 수정, eval 실행 및 성능 벤치마크 | https://github.com/anthropics/claude-plugins-official |

## 참고 스킬

| 이름 | 설명 | URL |
|------|------|-----|
| get-shit-done | Claude Code 스킬/에이전트 기반 개발 워크플로우 프레임워크 | https://github.com/gsd-build/get-shit-done |

## Status Line

`~/.claude/settings.json`에서 커스텀 status line을 설정하여 모델, 컨텍스트 사용량, 토큰 정보를 실시간으로 확인합니다.

**설정:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline.sh"
  }
}
```

**스크립트 (`~/.claude/statusline.sh`):**
```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

IN=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
OUT=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
CACHE_W=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
CACHE_R=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

fmt() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
DIM='\033[2m'; RESET='\033[0m'; BLUE='\033[34m'; MAGENTA='\033[35m'

if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

printf "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH\n"
printf "${BAR_COLOR}${BAR}${RESET} ${PCT}%% | ${GREEN}IN $(fmt $IN)${RESET} ${BLUE}OUT $(fmt $OUT)${RESET} ${DIM}📦 +$(fmt $CACHE_W) ♻$(fmt $CACHE_R)${RESET}\n"
```

**출력 예시:**
```
[Claude Opus 4.6] 📁 my-project | 🌿 main
████░░░░░░ 40% | IN 125,000 OUT 3,200 📦 +80,000 ♻45,000
```

- 컨텍스트 사용률에 따라 프로그레스 바 색상 변경 (초록 → 노랑 → 빨강)
- 현재 모델, 디렉토리, Git 브랜치, 입출력 토큰, 캐시 토큰 표시

## cmux 개발 환경 세팅

cmux 터미널에서 2x2 패널 워크스페이스를 자동 구성하는 스크립트입니다 (`~/cmux-setup.sh`).

**사용법:**
```bash
./cmux-setup.sh <워크스페이스이름>
# 또는 대화형으로 이름 입력
./cmux-setup.sh
```

**패널 구성:**
```
┌──────────────┬──────────────┐
│  설계        │  질문        │
│  (claude)    │  (claude)    │
├──────────────┼──────────────┤
│  작업        │  개발환경실행│
│  (claude)    │  (shell)     │
└──────────────┴──────────────┘
```

**동작 순서:**
1. cmux 워크스페이스 생성 및 이름 설정
2. 패널 4분할 (right → down × 2)
3. 각 패널 이름 설정 (설계, 작업, 질문, 개발 환경 실행)
4. 3개 패널에서 `claude` 실행 (설계/작업은 `--dangerously-skip-permissions`)
5. 완료 알림 전송

**스크립트 (`~/cmux-setup.sh`):**
```bash
#!/bin/bash

# cmux 개발 환경 자동 세팅 스크립트
# 사용법: ./cmux-setup.sh <워크스페이스이름>
#   또는: ./cmux-setup.sh  (대화형으로 이름 입력)

# ── 변수 입력 ──
WORKSPACE_NAME=${1:-}
if [ -z "$WORKSPACE_NAME" ]; then
  read -p "워크스페이스 이름을 입력하세요: " WORKSPACE_NAME
fi

if [ -z "$WORKSPACE_NAME" ]; then
  echo "오류: 워크스페이스 이름이 필요합니다."
  exit 1
fi

# ── 1. 워크스페이스 생성 및 전환 ──
echo "▶ 워크스페이스 생성: ${WORKSPACE_NAME}"
WS_RESULT=$(cmux new-workspace 2>&1)
echo "  $WS_RESULT"

# workspace ref 추출 (예: workspace:3)
WS_REF=$(echo "$WS_RESULT" | grep -oE 'workspace:[0-9]+')
if [ -z "$WS_REF" ]; then
  echo "오류: 워크스페이스 생성 실패"
  exit 1
fi

echo "▶ 워크스페이스 전환: ${WS_REF}"
cmux select-workspace --workspace "$WS_REF"
sleep 0.3

echo "▶ 워크스페이스 이름 설정: ${WORKSPACE_NAME}"
cmux workspace-action --action rename --workspace "$WS_REF" --title "$WORKSPACE_NAME"
sleep 0.3

# ── 2. 패널 구성 (2x2) ──
echo "▶ 패널 분할 시작"

# 초기 서피스 확인 (왼쪽 위가 될 패널)
LEFT_TOP=$(cmux tree --workspace "$WS_REF" 2>&1 | grep -oE 'surface:[0-9]+' | head -1)
echo "  초기 서피스: ${LEFT_TOP}"

# 오른쪽으로 분할 → 왼쪽 | 오른쪽
RIGHT_RESULT=$(cmux new-split right --workspace "$WS_REF" --surface "$LEFT_TOP" 2>&1)
RIGHT_TOP=$(echo "$RIGHT_RESULT" | grep -oE 'surface:[0-9]+')
echo "  오른쪽 분할: ${RIGHT_TOP}"
sleep 0.3

# 왼쪽 위에서 아래로 분할
LEFT_DOWN_RESULT=$(cmux new-split down --workspace "$WS_REF" --surface "$LEFT_TOP" 2>&1)
LEFT_BOTTOM=$(echo "$LEFT_DOWN_RESULT" | grep -oE 'surface:[0-9]+')
echo "  왼쪽 아래 분할: ${LEFT_BOTTOM}"
sleep 0.3

# 오른쪽 위에서 아래로 분할
RIGHT_DOWN_RESULT=$(cmux new-split down --workspace "$WS_REF" --surface "$RIGHT_TOP" 2>&1)
RIGHT_BOTTOM=$(echo "$RIGHT_DOWN_RESULT" | grep -oE 'surface:[0-9]+')
echo "  오른쪽 아래 분할: ${RIGHT_BOTTOM}"
sleep 0.3

echo ""
echo "  왼쪽 위 (설계):         ${LEFT_TOP}"
echo "  왼쪽 아래 (작업):       ${LEFT_BOTTOM}"
echo "  오른쪽 위 (질문):       ${RIGHT_TOP}"
echo "  오른쪽 아래 (개발환경): ${RIGHT_BOTTOM}"

# ── 3. 각 패널 이름 설정 ──
echo "▶ 패널 이름 설정"
cmux rename-tab --workspace "$WS_REF" --surface "$LEFT_TOP" "설계"
cmux rename-tab --workspace "$WS_REF" --surface "$LEFT_BOTTOM" "작업"
cmux rename-tab --workspace "$WS_REF" --surface "$RIGHT_TOP" "질문"
cmux rename-tab --workspace "$WS_REF" --surface "$RIGHT_BOTTOM" "개발 환경 실행"
sleep 0.3

# ── 4. 오른쪽 아래를 제외한 3개 패널에서 claude 실행 ──
echo "▶ Claude 실행 (설계, 작업, 질문 패널)"
cmux send --workspace "$WS_REF" --surface "$LEFT_TOP" $'claude --dangerously-skip-permissions\n'
sleep 0.3
cmux send --workspace "$WS_REF" --surface "$LEFT_BOTTOM" $'claude --dangerously-skip-permissions\n'
sleep 0.3
cmux send --workspace "$WS_REF" --surface "$RIGHT_TOP" $'claude\n'
sleep 0.3

# ── 5. 알림 전송 ──
echo "▶ 알림 전송"
cmux notify --title "개발 환경 준비완료" --body "설계 + 작업 + 질문 + 개발환경 실행 패널 구성"

echo ""
echo "✅ 워크스페이스 '${WORKSPACE_NAME}' 환경 세팅 완료!"
echo "   - 설계 (claude) | 질문 (claude)"
echo "   - 작업 (claude) | 개발 환경 실행"
```
