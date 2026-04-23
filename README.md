# Claude Code Setup

Claude Code에서 사용하는 커스텀 스킬 및 에이전트 아카이빙 프로젝트

## 디렉토리 구조

```
claude-code-setup/
├── scripts/
│   ├── statusline.sh
│   ├── cmux-setup.sh
│   └── .zshrc
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

| 이름 | 철학 | 핵심 특징 | 최적 환경 |
|------|------|----------|----------|
| [BMAD](https://github.com/bmad-code-org/BMAD-METHOD) | 엔터프라이즈 애자일, 문서 중심 | - PRD → 아키텍처 → 스토리 순서의 무거운 사전 기획<br>- PM/Architect 등 역할별 페르소나 에이전트를 마크다운으로 정의<br>- 문서 샤딩으로 컨텍스트 관리<br>- TDD 선택적<br>- Claude Code, Cursor 등 지원 | 대규모 팀, 감사/컴플라이언스 중요 환경 |
| [Superpowers](https://github.com/obra/superpowers) | 개발 규율 강제 (TDD + 코드리뷰) | - 브레인스토밍 → 플랜 → 실행 3단계 워크플로우<br>- TDD 필수 (테스트 없이 코드 쓰면 자동 삭제 후 재시작)<br>- 서브에이전트와 코드리뷰 에이전트 구조<br>- 코어 프롬프트 2K 토큰으로 경량<br>- git worktree 격리 지원<br>- Claude Code 중심 | 스펙 명확, 품질 요구 높은 프로젝트 |
| [GSD](https://github.com/gsd-build/get-shit-done) | 컨텍스트 엔지니어링, 실용주의 | - 탐색 허용하며 점진적 스펙 확정<br>- Goal-Backward 방식 검증<br>- 연구/기획/실행 에이전트 분리 및 독립 태스크 병렬(Wave) 실행<br>- 태스크마다 새 200K 컨텍스트로 컨텍스트 로트 방지<br>- 태스크별 원자적 git 커밋 (자동 revert 가능)<br>- Claude Code, Gemini, Codex, Cursor 등 10개+ 도구 지원 | 솔로 개발자의 탐색적 프로젝트 빠른 배포 |

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

**스크립트:** [`scripts/statusline.sh`](./scripts/statusline.sh)

**출력 예시:**
```
  [Opus 4.7] 📁 begins | 🌿 feature/harness
  ctx ░░░░░░░░░░ 0% | 5h ░░░░░░░░░░ 2% (3h 2m) | 7d ██░░░░░░░░ 24% (65h 2m)
```

- 컨텍스트 사용률에 따라 프로그레스 바 색상 변경 (초록 → 노랑 → 빨강)
- 현재 모델, 디렉토리, Git 브랜치 표시
- 5시간/7일 rate limit 사용률을 개별 프로그레스 바로 표시 (사용 가능 시에만 노출)
- rate limit 바도 70% 이상 노랑, 90% 이상 빨강으로 색상 변경

## cmux 개발 환경 세팅

cmux 터미널에서 2x2 패널 워크스페이스를 자동 구성하는 스크립트입니다.
`scripts/cmux-setup.sh` 와 `scripts/.zshrc` 를 **함께** 사용해야 전체 워크플로우가 동작합니다.

- `cmux-setup.sh` — 워크스페이스/패널 생성 + 에이전트 실행 + `~/.cmux-workspaces/<이름>.env` 파일 저장
- `.zshrc` 헬퍼 함수 — 저장된 env 파일을 현재 셸에 로드하고 pane으로 메시지를 전송

### 설치
```bash
# 1) 세팅 스크립트 배치
cp scripts/cmux-setup.sh ~/cmux-setup.sh
chmod +x ~/cmux-setup.sh

# 2) 헬퍼 함수를 ~/.zshrc 에 추가 (또는 내용을 직접 병합)
cat scripts/.zshrc >> ~/.zshrc
source ~/.zshrc
```

### 사용 흐름
```bash
# 1) 워크스페이스 생성 (패널 구성 + env 파일 저장)
~/cmux-setup.sh my-feature

# 2) env 파일을 현재 셸에 로드 → $DESIGN/$WORK/$ASK/$CMD/$CMUX_WS 주입
cmux-env my-feature

# 3) 변수 이름으로 pane 에 메시지 전송
csend "$WORK" "리팩터링 시작해줘"
cpaste "$WORK" "이 설계대로 구현해줘"   # 클립보드 내용 전송
```

### 패널 구성
```
┌──────────────┬──────────────┐
│  설계        │  질문        │
│  (claude)    │  (claude)    │
├──────────────┼──────────────┤
│  작업        │  터미널      │
│  (codex)     │  (shell)     │
└──────────────┴──────────────┘
```

### 동작 순서 (cmux-setup.sh)
1. cmux 워크스페이스 생성 및 이름 설정
2. 패널 4분할 (right → down × 2)
3. 각 패널 이름 설정 (설계, 작업, 질문, 터미널)
4. 에이전트 실행 — 설계/질문은 `claude --dangerously-skip-permissions`, 작업은 `codex`
5. `~/.cmux-workspaces/<이름>.env` 에 ref 저장 (`$CMUX_WS`, `$DESIGN`, `$WORK`, `$ASK`, `$CMD`)
6. 완료 알림 전송
7. 터미널 pane 에 ref 안내 메시지 출력

### .zshrc 헬퍼 함수
| 함수 | 설명 |
|------|------|
| `cmux-env <이름>` | env 파일을 현재 셸에 source (탭 자동완성 지원) |
| `csend <surface> <메시지>` | surface로 텍스트 + Enter 전송 |
| `cpaste <surface> [접두어]` | macOS 클립보드 내용을 surface로 전송 |
| `cmux-list` | 저장된 워크스페이스 env 파일 목록 |
| `cmux-prune` | cmux 앱에 존재하지 않는 죽은 env 파일 일괄 정리 |

**스크립트:** [`scripts/cmux-setup.sh`](./scripts/cmux-setup.sh), [`scripts/.zshrc`](./scripts/.zshrc)
