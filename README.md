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
