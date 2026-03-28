---
name: figma-to-jira
description: Figma 디자인 페이지를 분석하여 Jira 서브태스크를 자동 생성합니다. "figma에서 jira 태스크 생성", "디자인 기반 서브태스크 생성", "figma to jira" 등의 요청에 사용합니다.
argument-hint: [Figma URL, Jira 이슈 키, 참고 코드 영역 (선택)]
---

# Figma → Jira 서브태스크 생성 스킬

Figma 디자인 페이지를 분석하고, 기존 코드베이스와 비교하여 구현에 필요한 서브태스크를 분해한 뒤, Jira 서브태스크로 자동 생성하는 오케스트레이터입니다.

```
Phase 0: 입력 수집 및 MCP 연결 확인 + Jira 인증정보 추출
Phase A: figma-analyzer 에이전트 (Opus)  → 디자인 + 코드 분석, 태스크 분해
Phase B: 사용자 확인                      → 태스크 목록 검토 및 승인
Phase C: jira-creator 에이전트 (Sonnet)  → Jira 서브태스크 생성
Phase D: 검증                            → 생성된 이슈 필드 검증 및 보정
Phase E: 최종 보고
```

## 실행 절차

### Phase 0: 입력 수집 및 검증

#### 0-1. MCP 연결 확인

스킬 실행 시 가장 먼저 MCP 서버 연결 상태를 확인합니다:

1. **Figma MCP 확인**: `claude mcp list` 실행하여 figma 서버 존재 여부 확인
   - 미설정 시 → AskUserQuestion으로 안내:
     ```
     Figma MCP 서버가 설정되어 있지 않습니다.
     Figma Desktop 앱이 실행 중인 상태에서 자동으로 설정할까요? (예/아니오)
     ```
   - "예" 선택 시 → 아래 명령 실행:
     ```bash
     claude mcp add --transport sse figma http://127.0.0.1:3845/mcp --scope user
     ```
   - 설정 후 연결 테스트 수행. 실패 시 "Figma Desktop 앱을 실행 후 다시 시도해주세요" 안내

2. **Jira MCP 확인**: `claude mcp list` 실행하여 jira 서버 존재 여부 확인
   - 미설정 시 → AskUserQuestion으로 안내:
     ```
     Jira MCP 서버가 설정되어 있지 않습니다.
     설정하려면 다음 정보가 필요합니다:
     - Jira API 토큰 (https://id.atlassian.com/manage-profile/security/api-tokens)
     - Jira 계정 이메일
     자동으로 설정할까요? (예/아니오)
     ```
   - "예" 선택 시 → AskUserQuestion으로 이메일과 API 토큰을 순차적으로 입력 받은 후:
     ```bash
     claude mcp add --transport stdio jira \
       --env JIRA_URL=https://saramin.atlassian.net \
       --env JIRA_API_TOKEN={token} \
       --env JIRA_EMAIL={email} \
       --scope user \
       -- npx -y @aashari/mcp-server-atlassian-jira
     ```

3. **두 서버 모두 연결 확인 완료 후** 다음 단계로 진행

#### 0-1b. Jira 인증정보 추출 및 담당자 accountId 사전 조회

Jira MCP 서버의 환경 변수에서 인증정보를 추출하고, 담당자 accountId를 즉시 조회합니다:

1. `claude mcp get jira` 실행하여 JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN 값 추출
2. JIRA_EMAIL을 기본 담당자(assignee) 후보로 보관
3. AskUserQuestion으로 확인:
   ```
   담당자를 본인({JIRA_EMAIL})으로 지정할까요? (예 / 다른 이메일 입력)
   ```
4. `assignee_email` 확정 후 즉시 accountId 조회:
   ```bash
   curl -s -u "{jira_email}:{jira_api_token}" \
     "{jira_base_url}/rest/api/3/user/search?query={assignee_email}"
   ```
   - 응답에서 `accountId` 추출 → `assignee_account_id` 변수로 보관
   - **조회 실패 또는 결과 없음** → 사용자에게 안내 후 재입력 요청:
     ```
     해당 이메일({assignee_email})로 Jira 계정을 찾을 수 없습니다.
     이메일을 다시 확인해주세요. (다른 이메일 입력 또는 취소)
     ```
5. 추출된 `jira_email`, `jira_api_token`, `assignee_email`, **`assignee_account_id`** 를 이후 Phase A/C에서 사용할 변수로 보관
   - MCP 도구 실패 시 curl 폴백에 사용됨

#### 0-2. 입력 수집

`$ARGUMENTS`를 먼저 확인하여 파싱합니다:

**파싱 규칙:**
1. **Figma URL**: `https://www.figma.com/(design|file)/` 패턴으로 매칭
2. **Jira 이슈**: `https://saramin.atlassian.net/browse/[A-Z]+-\d+` URL 또는 `[A-Z]+-\d+` 키 패턴
3. **참고 영역**: `@` 접두사 경로 또는 `apps/`, `src/` 시작 경로
4. **검증**: Figma URL 1개 이상 + Jira 이슈 1개 필수

`$ARGUMENTS`가 비어있거나 필수 입력이 부족하면 AskUserQuestion으로 순차 수집:

1. Figma URL이 없으면:
   ```
   Figma 페이지 URL을 입력해주세요. (여러 개인 경우 줄 바꿈으로 구분)
   ```

2. Jira 이슈가 없으면:
   ```
   Jira 이슈 링크 또는 키를 입력해주세요. (예: SENIOR-255)
   ```

3. 참고 영역이 없으면 (선택):
   ```
   참고할 코드 영역이 있나요? (없으면 '없음'으로 입력)
   예: apps/senior/src/app/(private)/my/profile/, apps/senior/src/components/layout/
   ```

4. **Summary 접두사 선택**:
   ```
   서브태스크 Summary 접두사를 선택해주세요:
   1. [FE] (기본값)
   2. 직접 입력
   ```
   - "1" 또는 빈 입력 → `summary_prefix = "FE"`
   - "2" → AskUserQuestion으로 접두사 문자열 입력 받음 (예: "BE", "QA")

### Phase A: 디자인 및 코드 분석

진행률을 표시합니다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [Phase A] Figma 디자인 & 코드 분석 중...
  ██████░░░░░░░░░░░░░░░░░░░░░░░░ 20%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. 프로젝트 루트를 확인합니다 (`git rev-parse --show-toplevel`)

2. 워크스페이스 디렉토리를 생성합니다:
   ```bash
   mkdir -p {project_root}/.analysis/figma-to-jira-{이슈 키}
   ```
   - `workspace_dir = {project_root}/.analysis/figma-to-jira-{이슈 키}`

3. **Figma URL 수에 따라 분기합니다:**

   **URL이 1개인 경우:**
   - `output_path = {workspace_dir}/analyzer_total_result.json`
   - Agent 도구로 `figma-analyzer` 에이전트 1개 호출:
     ```
     Agent(
       description: "figma-analyzer: Figma 디자인 및 코드 분석",
       prompt: "당신은 figma-analyzer 에이전트입니다.
         ~/.claude/agents/figma-analyzer/AGENT.md의 지시를 따르세요.

         figma_urls: [{url}]
         output_path: {workspace_dir}/analyzer_total_result.json
         jira_issue_key: {이슈 키}
         code_paths: {참고 영역 목록}
         project_root: {프로젝트 루트}
         start_date: {사용자 입력 시작일 또는 null}
         summary_prefix: {접두사 값, 예: FE}"
     )
     ```
   - 에이전트 결과에 `===DONE===` 포함 여부로 성공 확인

   **URL이 N개인 경우 (N > 1):**
   - 단일 메시지에 N개 Agent 도구 호출 (병렬 처리):
     ```
     # 동시에 N개 호출 (같은 메시지에)
     Agent(
       description: "figma-analyzer: URL 1 분석",
       prompt: "당신은 figma-analyzer 에이전트입니다.
         ~/.claude/agents/figma-analyzer/AGENT.md의 지시를 따르세요.

         figma_urls: [{url_1}]
         output_path: {workspace_dir}/analyzer_result_1.json
         jira_issue_key: {이슈 키}
         code_paths: {참고 영역 목록}
         project_root: {프로젝트 루트}
         start_date: {사용자 입력 시작일 또는 null}
         summary_prefix: {접두사 값, 예: FE}"
     )
     Agent(
       description: "figma-analyzer: URL 2 분석",
       prompt: "당신은 figma-analyzer 에이전트입니다.
         ~/.claude/agents/figma-analyzer/AGENT.md의 지시를 따르세요.

         figma_urls: [{url_2}]
         output_path: {workspace_dir}/analyzer_result_2.json
         ...동일한 파라미터..."
     )
     # ... N번째까지 반복
     ```
   - 모든 에이전트 완료 후 결과 통합 (오케스트레이터가 직접 수행):
     1. Read 도구로 `analyzer_result_1.json` ~ `analyzer_result_N.json` 순서대로 읽기
     2. 각 파일의 `tasks` 배열을 하나로 병합
     3. `order` 필드를 1부터 재정렬
     4. 태스크 간 의존성 재검토 및 중복 제거
     5. `total_tasks` 업데이트
     6. Write 도구로 통합 결과를 `{workspace_dir}/analyzer_total_result.json`에 저장

   > **주의**: `model` 파라미터를 지정하지 않습니다. 기본 에이전트로 호출해야 MCP 도구(Figma 등)에 접근할 수 있습니다.

### Phase B: 사용자 확인

Read 도구로 `{workspace_dir}/analyzer_total_result.json`을 읽어 분석 결과를 정리하여 표시합니다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Figma → Jira 서브태스크 생성
  상위 이슈: {JIRA_ISSUE_KEY}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

총 N개의 서브태스크:

1. [{prefix}] {category}: {title}
   - Figma: {node_id}
   - 구현 범위: 컴포넌트 N개, API N개
   - 기간: {start_date} ~ {due_date} ({estimated_days}일, 버퍼 포함)

2. [{prefix}] {category}: {title}
   ...
```

1. **작업 시작일 질문** (start_date가 아직 없는 경우):
   AskUserQuestion으로 질문:
   ```
   첫 태스크의 시작일을 입력해주세요. (YYYY-MM-DD, 예: 2026-03-19)
   ```
   입력받은 시작일 기준으로 각 태스크의 startDate/dueDate를 재산정하여 표시

2. **최종 확인**:
   AskUserQuestion으로 선택지 제공:
   ```
   위 서브태스크 목록을 확인해주세요:
   1. 생성 진행 — Jira에 서브태스크를 생성합니다
   2. 수정 — 수정할 내용을 알려주세요
   3. 취소 — 중단합니다
   ```

   - **"생성 진행" 또는 "1"** → Phase C로 진행
   - **"수정" 또는 "2"** → 사용자 피드백을 반영하여 태스크 목록 수정 후 다시 확인
   - **"취소" 또는 "3"** → 스킬 실행 중단

### Phase C: Jira 서브태스크 생성

진행률을 업데이트합니다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [Phase C] Jira 서브태스크 생성 중...
  ██████████████████░░░░░░░░░░░░ 60%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. Agent 도구로 `jira-creator` 에이전트를 호출합니다:

   ```
   Agent(
     description: "jira-creator: Jira 서브태스크 생성",
     model: "sonnet",
     prompt: "당신은 jira-creator 에이전트입니다.
       ~/.claude/agents/jira-creator/AGENT.md의 지시를 따르세요.

       task_breakdown_path: {project_root}/.analysis/figma-to-jira-{이슈 키}/analyzer_total_result.json
       parent_issue_key: {상위 이슈 키}
       jira_base_url: https://saramin.atlassian.net
       jira_email: {추출된 JIRA_EMAIL}
       jira_api_token: {추출된 JIRA_API_TOKEN}
       assignee_account_id: {Phase 0-1b에서 조회한 accountId}
       summary_prefix: {접두사 값, 예: FE}"
   )
   ```

2. 에이전트 결과에서 `===JIRA_RESULT===` ... `===END===` 블록을 파싱하여 생성 결과 추출

### Phase D: 검증

생성된 이슈의 핵심 필드를 검증하고, 누락된 필드를 보정합니다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [Phase D] 생성된 이슈 검증 중...
  ████████████████████████░░░░░░ 80%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. 각 생성된 이슈에 대해 Jira MCP 도구(또는 curl 폴백)로 조회:
   - **assignee**: 담당자가 설정되어 있는지 확인. 누락 시 `assignee_email`로 보정
   - **startDate** (`customfield_10015`): 시작일이 설정되어 있는지 확인. 누락 시 보정
   - **dueDate**: 종료일이 설정되어 있는지 확인. 누락 시 보정

2. 누락된 필드가 있으면 Jira MCP 도구(또는 curl 폴백)로 업데이트

3. 검증 결과를 기록:
   - 보정된 이슈 목록
   - 보정 실패한 이슈 목록 (있는 경우)

### Phase E: 최종 보고

생성 및 검증 결과를 사용자에게 보고합니다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  생성 완료! ({success}개 성공 / {total}개)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{issue_key}: {summary}
  → {url}
  👤 {assignee}
  📅 {start_date} ~ {due_date}

{issue_key}: {summary}
  → {url}
  👤 {assignee}
  📅 {start_date} ~ {due_date}
...
```

검증에서 보정된 항목이 있는 경우:
```
🔧 보정된 필드:
- {issue_key}: {보정 내용}
```

실패한 태스크가 있는 경우:
```
⚠️ 생성 실패 ({failed}개):
- {summary}: {error}
```

## 중요 규칙

1. **Phase 순서 준수** — 0→A→B→C→D→E 순서를 반드시 지킴
2. **MCP 연결 먼저 확인** — Phase 0에서 두 서버 모두 연결 확인 후 진행
3. **사용자 확인 필수** — Phase B에서 사용자 승인 없이 Jira 생성하지 않음
4. **에러 시 안내** — MCP 연결 실패, 분석 실패 등 에러 발생 시 명확한 안내와 대안 제시
5. **입력 검증** — Figma URL과 Jira 이슈 키 형식을 검증
6. **중복 방지** — 동일한 서브태스크가 이미 존재하는지 확인
7. **MCP 도구 우선 사용** — Jira/Figma 작업 시 MCP 도구를 먼저 시도하고, 실패 시 curl 폴백
8. **Jira REST API v3 사용** — 검색 시 `/rest/api/3/search/jql` 사용 (deprecated `/rest/api/3/search` 대신)
