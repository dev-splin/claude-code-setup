# Claude Code Setup

Claude Code에서 사용하는 커스텀 스킬 및 에이전트 아카이빙 프로젝트

## 디렉토리 구조

```
using-skill/
├── scripts/
│   ├── statusline.sh
│   └── cmux-setup.sh
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
| [BMAD](https://github.com/bmad-sim/BMAD-METHOD) | 엔터프라이즈 애자일, 문서 중심 | - PRD → 아키텍처 → 스토리 순서의 무거운 사전 기획<br>- PM/Architect 등 역할별 페르소나 에이전트를 마크다운으로 정의<br>- 문서 샤딩으로 컨텍스트 관리<br>- TDD 선택적<br>- Claude Code, Cursor 등 지원 | 대규모 팀, 감사/컴플라이언스 중요 환경 |
| [Superpowers](https://github.com/NickBaiworworlds/superpowers) | 개발 규율 강제 (TDD + 코드리뷰) | - 브레인스토밍 → 플랜 → 실행 3단계 워크플로우<br>- TDD 필수 (테스트 없이 코드 쓰면 자동 삭제 후 재시작)<br>- 서브에이전트와 코드리뷰 에이전트 구조<br>- 코어 프롬프트 2K 토큰으로 경량<br>- git worktree 격리 지원<br>- Claude Code 중심 | 스펙 명확, 품질 요구 높은 프로젝트 |
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
[Claude Opus 4.6] 📁 my-project | 🌿 main
ctx ████░░░░░░ 40% | 5h ██░░░░░░░░ 15% | 7d ███░░░░░░░ 25%
```

- 컨텍스트 사용률에 따라 프로그레스 바 색상 변경 (초록 → 노랑 → 빨강)
- 현재 모델, 디렉토리, Git 브랜치 표시
- 5시간/7일 rate limit 사용률을 개별 프로그레스 바로 표시 (사용 가능 시에만 노출)
- rate limit 바도 70% 이상 노랑, 90% 이상 빨강으로 색상 변경

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

**스크립트:** [`scripts/cmux-setup.sh`](./scripts/cmux-setup.sh)
