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

# ── 4. 에이전트 실행 (작업 pane은 codex) ──
echo "▶ 에이전트 실행"
cmux send --workspace "$WS_REF" --surface "$LEFT_TOP"    $'claude --dangerously-skip-permissions\n'
sleep 0.3
cmux send --workspace "$WS_REF" --surface "$LEFT_BOTTOM" $'codex\n'
sleep 0.3
cmux send --workspace "$WS_REF" --surface "$RIGHT_TOP"   $'claude --dangerously-skip-permissions\n'
sleep 0.3

# ── 5. ref를 env 파일로 저장 ──
CMUX_ENV_DIR="${HOME}/.cmux-workspaces"
mkdir -p "$CMUX_ENV_DIR"
ENV_FILE="${CMUX_ENV_DIR}/${WORKSPACE_NAME}.env"

cat > "$ENV_FILE" <<EOF
# cmux workspace: ${WORKSPACE_NAME}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
export CMUX_WS="${WS_REF}"
export DESIGN="${LEFT_TOP}"       # 설계 (claude)
export WORK="${LEFT_BOTTOM}"      # 작업 (codex)
export ASK="${RIGHT_TOP}"         # 질문 (claude)
export DEV="${RIGHT_BOTTOM}"      # 개발 환경 실행
export CMUX_CURRENT_WS="${WORKSPACE_NAME}"
EOF

echo "▶ ref 저장: ${ENV_FILE}"

# ── 6. 알림 전송 ──
echo "▶ 알림 전송"
cmux notify --title "개발 환경 준비완료" --body "${WORKSPACE_NAME}: 설계/작업(codex)/질문/개발환경"

echo ""
echo "✅ 워크스페이스 '${WORKSPACE_NAME}' 환경 세팅 완료!"
echo "   - 설계 (claude)  |  질문 (claude)"
echo "   - 작업 (codex)   |  개발 환경 실행"
echo ""
echo "💡 셸에서 ref 사용하려면:"
echo "   cmux-env ${WORKSPACE_NAME}"
echo "   csend \"\$WORK\" \"리팩터링 시작해줘\""