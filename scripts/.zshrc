# ═══════════════════════════════════════════════════════════════
# cmux 헬퍼 함수 모음
# ═══════════════════════════════════════════════════════════════
# 이 블록은 cmux(AI 코딩 에이전트용 macOS 터미널)의 pane을
# 변수 이름으로 쉽게 제어하기 위한 커스텀 함수들입니다.
#
# 사전 준비:
#   - cmux-setup.sh 가 ~/.cmux-workspaces/<이름>.env 파일을
#     생성해둔 상태여야 합니다.
#   - 각 env 파일에는 $DESIGN / $WORK / $ASK / $DEV 같은
#     surface ref 변수가 export 되어 있습니다.
#   - ~/.zshrc에 넣은 후 source ~/.zshrc 를 실행하면며 적용됩니다.
#
# 사용 흐름:
#   1) ./cmux-setup.sh my-feature    # env 파일 생성
#   2) cmux-env my-feature           # 이 셸에 변수 로드
#   3) csend "$WORK" "메시지"        # 변수 이름으로 전송
# ═══════════════════════════════════════════════════════════════

# env 파일이 저장될 디렉토리 경로
# CMUX_ENV_DIR 이라는 이름으로 export 해두면
# 아래 함수들은 물론, cmux-setup.sh 같은 외부 스크립트에서도
# 같은 경로를 참조할 수 있습니다.
export CMUX_ENV_DIR="${HOME}/.cmux-workspaces"


# ───────────────────────────────────────────────────────────────
# cmux-env : 저장된 워크스페이스 env 파일을 현재 셸에 로드
# ───────────────────────────────────────────────────────────────
# 사용법 : cmux-env <워크스페이스이름>
# 예시   : cmux-env my-feature
#
# 동작   :
#   1) ~/.cmux-workspaces/<이름>.env 파일이 있는지 확인
#   2) source 로 파일을 읽어 $DESIGN, $WORK 등을 현재 셸에 주입
#   3) 해당 워크스페이스가 cmux 앱에 실제로 살아있는지 검증
#   4) 이미 닫힌 워크스페이스라면 env 파일 삭제 여부를 사용자에게 확인
# ───────────────────────────────────────────────────────────────
cmux-env() {
  # $1 = 사용자가 입력한 워크스페이스 이름 (예: "my-feature")
  local name=$1

  # env 파일의 전체 경로를 조립
  # 예: /Users/user/.cmux-workspaces/my-feature.env
  local file="${CMUX_ENV_DIR}/${name}.env"

  # -f : "파일이 실제로 존재하면 참"
  # ! -f : "존재하지 않으면" 이라는 의미
  if [ ! -f "$file" ]; then
    echo "워크스페이스 env 없음: $file"
    # return 1 : 함수를 오류 상태(0이 아닌 값)로 종료
    #           (exit 1 은 셸 자체를 종료시키므로 사용 금지)
    return 1
  fi

  # source : 파일에 적힌 명령(export ...)을 현재 셸에서 실행
  #          → 파일 안의 변수들이 셸의 환경변수로 등록됨
  source "$file"

  # ── 유효성 검사 ──
  # cmux 앱 안에서 워크스페이스가 아직 살아있는지 확인.
  # 워크스페이스를 닫으면 cmux 내부 ref는 사라지지만,
  # 우리가 만든 .env 파일은 파일시스템에 그대로 남아있기 때문에
  # "죽은 ref"를 가리키는 상태가 될 수 있음.
  #
  # cmux list-workspaces : 현재 살아있는 워크스페이스 목록 출력
  # 2>/dev/null           : 에러 메시지가 화면에 안 찍히도록 버림
  # grep -q "$CMUX_WS"    : 목록에 $CMUX_WS(예: workspace:3) 가 있으면 참
  #                         (-q 는 결과를 출력하지 않고 조용히 검사만)
  # ! ... ; then          : 없으면(= 워크스페이스가 죽었으면) 아래 블록 실행
  if ! cmux list-workspaces 2>/dev/null | grep -q "$CMUX_WS"; then
    echo "⚠️  $CMUX_WS 가 cmux에 존재하지 않습니다 (이미 닫힌 듯)"

    # 사용자에게 env 파일을 지울지 물어봄.
    # zsh 의 read 문법은 `read "변수명?프롬프트문구"` 형태.
    #   (bash 는 `read -p "프롬프트" 변수명` 인데,
    #    이 파일은 ~/.zshrc 전용이므로 zsh 문법을 씀)
    read "reply?env 파일을 삭제할까요? [y/N] "

    # [[ ... =~ ... ]] : 문자열이 정규식과 매칭되는지 검사
    # ^[Yy]$           : 맨 처음/끝이 Y 또는 y 한 글자인 경우만 참
    #                    → 엔터만 눌렀거나 n 이면 거짓 (기본값 No)
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      rm "$file"
      echo "✓ 삭제됨: $file"
    fi

    # 워크스페이스가 죽은 상태이므로 로드를 중단
    return 1
  fi

  # ── 정상 로드 완료 안내 ──
  # $CMUX_WS 등은 방금 source 한 env 파일에서 주입된 변수들
  echo "✓ 로드됨: $name ($CMUX_WS)"
  # \$ 로 이스케이프 : echo 가 변수로 확장하지 않고 "$DESIGN" 이라는
  #                    글자 그대로 찍히게 함 (그 뒤 = 뒤쪽은 실제 값)
  echo "  \$DESIGN=$DESIGN  \$WORK=$WORK  \$ASK=$ASK  \$DEV=$DEV"
}


# ───────────────────────────────────────────────────────────────
# csend : 특정 surface 에 텍스트 + Enter 를 한 번에 전송
# ───────────────────────────────────────────────────────────────
# 사용법 : csend <surface> <보낼 문자열...>
# 예시   : csend "$WORK" "리팩터링 시작해줘"
#
# 왜 필요한가:
#   cmux send 는 텍스트만 입력할 뿐 Enter 를 누르지 않기 때문에,
#   실행까지 원한다면 send-key Enter 를 따로 호출해야 함.
#   매번 두 줄 치기 귀찮으니 한 함수로 묶음.
# ───────────────────────────────────────────────────────────────
csend() {
  # 첫 인자를 surface 에 담고, 위치 인자 목록에서 제거
  local surface=$1
  # shift : $1 을 버리고 $2→$1, $3→$2 로 한 칸씩 당김
  #         → 이후 $* 는 surface 를 제외한 나머지 단어들을 가리킴
  shift

  # cmux send : surface 의 터미널에 문자열을 "타이핑"만 함 (Enter X)
  # "$*"      : 남은 모든 인자를 공백으로 이어붙인 한 줄 문자열
  cmux send --surface "$surface" "$*"

  # cmux send-key : surface 에 Enter 키를 "눌러" 명령을 실행시킴
  cmux send-key --surface "$surface" Enter
}


# ───────────────────────────────────────────────────────────────
# cmux-list : 저장된 워크스페이스 env 파일 목록 출력
# ───────────────────────────────────────────────────────────────
# 사용법 : cmux-list
# 출력 예:
#   my-feature
#   auth-refactor
#   ui-polish
# ───────────────────────────────────────────────────────────────
cmux-list() {
  # ls -1          : 한 줄에 하나씩 나열
  # 2>/dev/null    : 디렉토리가 아직 없을 때 뜨는 에러를 숨김
  # sed 's/...//'  : 뒤의 ".env" 확장자를 제거해서 이름만 보여줌
  ls -1 "$CMUX_ENV_DIR" 2>/dev/null | sed 's/\.env$//'
}


# ───────────────────────────────────────────────────────────────
# cpaste : macOS 클립보드 내용을 지정 surface 로 전송
# ───────────────────────────────────────────────────────────────
# 사용법 :
#   cpaste <surface>                  # 클립보드 내용만
#   cpaste <surface> <앞에 붙일 문구> # 문구 + 빈 줄 + 클립보드
#
# 예시   :
#   # (Claude Code 답변을 마우스 드래그 → Cmd+C 후)
#   cpaste "$WORK" "이 설계대로 구현해줘"
#
# 동작 원리: pbpaste 는 macOS 전용 명령으로, 현재 클립보드 내용을
#            표준 출력으로 내보냅니다. 그 결과를 $(...) 로 받아
#            csend 에 그대로 넘겨줍니다.
# ───────────────────────────────────────────────────────────────
cpaste() {
  local surface=$1
  shift  # surface 를 위치 인자에서 제거

  # 남은 인자들을 공백으로 이어붙여 prefix(앞에 붙일 문구) 로 사용.
  # 인자가 하나도 없으면 prefix 는 빈 문자열이 됨.
  local prefix="$*"

  # 클립보드 내용을 변수에 저장
  # (pbpaste 를 if 문과 csend 에서 각각 호출하면 그 사이에 클립보드가
  #  바뀔 수 있으니, 딱 한 번만 읽어두는 편이 안전)
  local clipboard
  clipboard=$(pbpaste)

  # -z : "문자열이 비어있으면 참"
  # 클립보드가 비어있으면 실수 방지를 위해 전송 중단
  if [ -z "$clipboard" ]; then
    # >&2 : 표준 에러(stderr) 로 출력. 성공 출력과 구분해서
    #       파이프 연결 시 의도치 않게 섞이지 않도록 함.
    echo "⚠️  클립보드가 비어있습니다" >&2
    return 1
  fi

  # prefix 가 있으면 "문구 + 빈 줄 + 클립보드" 형태로,
  # 없으면 클립보드만 그대로 전송.
  # 문자열 리터럴 안의 실제 개행은 쌍따옴표 안에서 그대로 보존됨.
  if [ -n "$prefix" ]; then
    csend "$surface" "${prefix}

${clipboard}"
  else
    csend "$surface" "$clipboard"
  fi
}


# ───────────────────────────────────────────────────────────────
# cmux-prune : 죽은 워크스페이스의 env 파일을 일괄 정리
# ───────────────────────────────────────────────────────────────
# 사용법 : cmux-prune
# 저장된 env 파일을 모두 훑어서, cmux 앱에 더 이상 존재하지 않는
# 워크스페이스의 env 파일들을 한 번에 삭제합니다.
# ───────────────────────────────────────────────────────────────
cmux-prune() {
  # 삭제한 파일 수 카운터
  local cleaned=0

  # $CMUX_ENV_DIR 안의 모든 .env 파일을 순회
  for file in "$CMUX_ENV_DIR"/*.env; do
    # 디렉토리가 비어있으면 glob 이 확장되지 않고 문자 그대로 남을 수 있음.
    # [ -f "$file" ] || continue 는 "파일 아니면 건너뜀" 이라는 안전장치.
    [ -f "$file" ] || continue

    # 파일에서 workspace:N 형태의 ref 를 추출
    # -o : 매칭된 부분만 출력
    # -E : 확장 정규식 사용
    # head -1 : 여러 개여도 첫 줄만
    local ws_ref
    ws_ref=$(grep -oE 'workspace:[0-9]+' "$file" | head -1)

    # ref 가 있고, 그 ref 가 cmux 에 더 이상 존재하지 않는 경우만 삭제
    if [ -n "$ws_ref" ] && ! cmux list-workspaces 2>/dev/null | grep -q "$ws_ref"; then
      # basename file .env : 경로와 확장자를 제거해서 이름만 추출
      # 예: /Users/user/.cmux-workspaces/old.env → old
      echo "죽은 워크스페이스 정리: $(basename "$file" .env) ($ws_ref)"
      rm "$file"
      # bash/zsh 공통: 수식 연산은 $(( ... )) 안에서
      cleaned=$((cleaned + 1))
    fi
  done

  echo "✓ ${cleaned}개 정리 완료"
}


# ───────────────────────────────────────────────────────────────
# zsh 자동완성 : cmux-env 뒤에 탭 누르면 저장된 이름 목록이 나옴
# ───────────────────────────────────────────────────────────────
# 예: cmux-env my<Tab> → my-feature 로 자동 완성
#
# -n "$ZSH_VERSION" : zsh 에서만 등록 (bash 에서 에러 방지)
# compadd           : zsh 자동완성 엔진에 후보 단어들을 등록
# compdef           : 특정 명령에 자동완성 함수를 연결
# ───────────────────────────────────────────────────────────────
if [ -n "$ZSH_VERSION" ]; then
  _cmux_env_complete() {
    # cmux-list 가 뱉는 이름들을 자동완성 후보로 추가
    compadd $(cmux-list)
  }
  # cmux-env 이름 뒤에 Tab 누르면 후보 자동완성
  compdef _cmux_env_complete cmux-env
fi

# ═══════════════════════════════════════════════════════════════
# 끝
# ═══════════════════════════════════════════════════════════════