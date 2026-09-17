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

# ── 2. 패널 구성 (세로 3분할) ──
echo "▶ 패널 분할 시작"

# 초기 서피스 확인 (왼쪽이 될 패널)
LEFT=$(cmux tree --workspace "$WS_REF" 2>&1 | grep -oE 'surface:[0-9]+' | head -1)
echo "  초기 서피스: ${LEFT}"

# 왼쪽에서 오른쪽으로 분할 → 왼쪽 | 가운데
MIDDLE_RESULT=$(cmux new-split right --workspace "$WS_REF" --surface "$LEFT" 2>&1)
MIDDLE=$(echo "$MIDDLE_RESULT" | grep -oE 'surface:[0-9]+')
echo "  가운데 분할: ${MIDDLE}"
sleep 0.3

# 가운데에서 오른쪽으로 분할 → 왼쪽 | 가운데 | 오른쪽
RIGHT_RESULT=$(cmux new-split right --workspace "$WS_REF" --surface "$MIDDLE" 2>&1)
RIGHT=$(echo "$RIGHT_RESULT" | grep -oE 'surface:[0-9]+')
echo "  오른쪽 분할: ${RIGHT}"
sleep 0.3

echo ""
echo "  왼쪽 (설계):     ${LEFT}"
echo "  가운데 (작업):   ${MIDDLE}"
echo "  오른쪽 (리뷰):   ${RIGHT}"

# ── 3. 패널 폭 3등분 보정 ──
# new-split 은 항상 절반으로 나누므로 이 시점 비율은 1/2 : 1/4 : 1/4 이다.
# 왼쪽 경계를 왼쪽으로 밀면 안쪽 경계(0.5)는 유지된 채 오른쪽 두 패널이 함께
# 커지므로 셋 다 1/3 이 된다. --amount 는 픽셀 단위라 칸 → 픽셀 환산이 필요하다.
echo "▶ 패널 폭 3등분 보정"

PANE_LIST=$(cmux list-panes --workspace "$WS_REF" 2>&1 | grep -oE 'pane:[0-9]+')
LEFT_PANE=$(echo "$PANE_LIST" | sed -n 1p)
MIDDLE_PANE=$(echo "$PANE_LIST" | sed -n 2p)
COLS_DIR="/tmp/cmux-setup-$$"
mkdir -p "$COLS_DIR"

# 서피스의 폭(칸)을 파일로 받아온다. 셸 기동 전에는 입력이 삼켜지므로 파일이
# 생길 때까지 재전송한다 (삼켜진 입력은 화면에 남지 않아 깜빡임이 없다).
measure_cols() {
  local surface=$1 out=$2 attempt i
  for attempt in 1 2 3 4 5; do
    cmux send --workspace "$WS_REF" --surface "$surface" "tput cols > $out"$'\n' >/dev/null 2>&1
    for i in 1 2 3 4 5; do
      sleep 0.3
      [ -s "$out" ] && { cat "$out"; return; }
    done
  done
  echo 0
}

# 왼쪽 경계 이동 (양수: 왼쪽으로, 음수: 오른쪽으로)
# -L 은 해당 pane 의 왼쪽 경계를, -R 은 오른쪽 경계를 움직인다.
move_border() {
  if [ "$1" -gt 0 ]; then
    cmux resize-pane --pane "$MIDDLE_PANE" --workspace "$WS_REF" -L --amount "$1"
  elif [ "$1" -lt 0 ]; then
    cmux resize-pane --pane "$LEFT_PANE" --workspace "$WS_REF" -R --amount "$(( -$1 ))"
  fi
}

L_COLS=$(measure_cols "$LEFT" "$COLS_DIR/l")
M_COLS=$(measure_cols "$MIDDLE" "$COLS_DIR/m")

if [ -n "$MIDDLE_PANE" ] && [ "$L_COLS" -gt 0 ] && [ "$M_COLS" -gt 0 ]; then
  # 가운데와 오른쪽은 항상 같으므로 전체 폭은 L + 2M 이다
  TARGET=$(( (L_COLS + 2 * M_COLS) / 3 ))

  # 1차: 셀 너비를 7px 로 가정하고 이동
  MOVE=$(( (L_COLS - TARGET) * 7 ))
  move_border "$MOVE"

  # 2차: 실제 이동한 칸 수로 셀 너비를 역산해 잔차 보정
  L_NOW=$(measure_cols "$LEFT" "$COLS_DIR/l2")
  if [ "$L_NOW" -gt 0 ] && [ "$L_NOW" -ne "$L_COLS" ]; then
    move_border "$(( (L_NOW - TARGET) * MOVE / (L_COLS - L_NOW) ))"
  fi
  echo "  ${L_COLS}/${M_COLS}/${M_COLS} 칸 → 각 ${TARGET} 칸"
else
  echo "  폭 측정 실패 — 기본 비율 유지"
fi
rm -rf "$COLS_DIR"

# 측정 흔적 지우기
for s in "$LEFT" "$MIDDLE" "$RIGHT"; do
  cmux send --workspace "$WS_REF" --surface "$s" $'clear\n' >/dev/null 2>&1
done
sleep 0.3

# ── 4. 각 패널 이름 설정 ──
echo "▶ 패널 이름 설정"
cmux rename-tab --workspace "$WS_REF" --surface "$LEFT" '설계[$DESIGN]'
cmux rename-tab --workspace "$WS_REF" --surface "$MIDDLE" '작업[$WORK]'
cmux rename-tab --workspace "$WS_REF" --surface "$RIGHT" '리뷰[$REVIEW]'
sleep 0.3

# ── 5. 에이전트 실행 ──
echo "▶ 에이전트 실행"
cmux send --workspace "$WS_REF" --surface "$LEFT"   $'claude --dangerously-skip-permissions\n'
sleep 0.3
cmux send --workspace "$WS_REF" --surface "$MIDDLE" $'claude --dangerously-skip-permissions\n'
sleep 0.3
cmux send --workspace "$WS_REF" --surface "$RIGHT"  $'claude --dangerously-skip-permissions\n'
sleep 0.3

# ── 6. ref를 env 파일로 저장 ──
CMUX_ENV_DIR="${HOME}/.cmux-workspaces"
mkdir -p "$CMUX_ENV_DIR"
ENV_FILE="${CMUX_ENV_DIR}/${WORKSPACE_NAME}.env"

cat > "$ENV_FILE" <<EOF
# cmux workspace: ${WORKSPACE_NAME}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
export CMUX_WS="${WS_REF}"
export DESIGN="${LEFT}"       # 설계 (claude)
export WORK="${MIDDLE}"       # 작업 (claude)
export REVIEW="${RIGHT}"      # 리뷰 (claude)
export CMUX_CURRENT_WS="${WORKSPACE_NAME}"
EOF

echo "▶ ref 저장: ${ENV_FILE}"

# ── 7. 알림 전송 ──
echo "▶ 알림 전송"
cmux notify --title "개발 환경 준비완료" --body "${WORKSPACE_NAME}: 설계/작업/리뷰"

# ── 8. 안내 메시지 출력 ──
echo ""
echo "✅ 워크스페이스 '${WORKSPACE_NAME}' (\$CMUX_WS) 환경 세팅 완료!"
echo '   - 설계 (claude) [$DESIGN] | 작업 (claude) [$WORK] | 리뷰 (claude) [$REVIEW]'
echo ""
echo "💡 셸에서 ref 사용하려면:"
echo "   cmux-env ${WORKSPACE_NAME}"
echo '   csend "$WORK" "리팩터링 시작해줘"'
echo ""
