#!/bin/bash
#
# Keep Awake — 맥북이 잠들지 않게 하는 SwiftBar 플러그인
# macOS 내장 caffeinate 를 이용합니다.
#
# <swiftbar.title>Keep Awake</swiftbar.title>
# <swiftbar.version>1.0</swiftbar.version>
# <swiftbar.author>Claude</swiftbar.author>
# <swiftbar.desc>caffeinate 로 맥북 잠자기를 차단/해제합니다.</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

PIDFILE="$HOME/.keep-awake.pid"

is_running() {
  [ -f "$PIDFILE" ] || return 1
  local pid
  pid=$(cat "$PIDFILE" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

stop_caffeinate() {
  if [ -f "$PIDFILE" ]; then
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$PIDFILE"
  fi
}

# caffeinate 플래그
#   -d 디스플레이 잠자기 방지 / -i 시스템 유휴 잠자기 방지
#   -m 디스크 잠자기 방지     / -s 시스템 잠자기 방지(AC 전원 시)
#   -u 사용자 활성 상태 선언
start_caffeinate() {
  stop_caffeinate
  nohup caffeinate -dimsu >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
}

start_caffeinate_locked() {
  stop_caffeinate
  # 화면은 꺼지되(-d 제외) 시스템은 깨어 있게
  nohup caffeinate -imsu >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
  # 지금 바로 화면 끄기(잠금 설정돼 있으면 잠금)
  pmset displaysleepnow
}

# ---- 액션 처리 (메뉴 클릭 시 인자와 함께 재실행됨) ----
case "$1" in
  on)     start_caffeinate;        exit 0 ;;
  lock)   start_caffeinate_locked; exit 0 ;;
  off)    stop_caffeinate;         exit 0 ;;
  folder) open "$HOME/.swiftbar-plugins";              exit 0 ;;
  edit)   open -e "$0";                                exit 0 ;;
  quit)   osascript -e 'tell application "SwiftBar" to quit' >/dev/null 2>&1; exit 0 ;;
esac

# ---- 메뉴 그리기 ----
SCRIPT="$0"

if is_running; then
  # 메뉴바 아이콘: 켜진 커피잔
  echo ":cup.and.saucer.fill: | sfcolor=#F5A623"
  echo "---"
  echo "잠자기 차단 중 ☕️ | color=#8E8E93 size=13"
  echo "---"
  echo "잠자기 차단 해제 | bash=\"$SCRIPT\" param1=off terminal=false refresh=true"
else
  # 메뉴바 아이콘: 잠자는 달
  echo ":moon.zzz.fill: | sfcolor=#8E8E93"
  echo "---"
  echo "잠자기 허용 중 😴 | color=#8E8E93 size=13"
  echo "---"
  echo "잠자기 차단 | bash=\"$SCRIPT\" param1=on terminal=false refresh=true"
  echo "잠자기 차단 + 화면 잠금 | bash=\"$SCRIPT\" param1=lock terminal=false refresh=true"
fi
echo "---"
echo "Settings"
echo "--플러그인 폴더 열기 | bash=\"$SCRIPT\" param1=folder terminal=false"
echo "--스크립트 편집기 열기 | bash=\"$SCRIPT\" param1=edit terminal=false"
echo "--전체 새로고침 | href=swiftbar://refreshallplugins"
echo "--SwiftBar 종료 | bash=\"$SCRIPT\" param1=quit terminal=false"
