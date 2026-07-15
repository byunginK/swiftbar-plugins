#!/bin/bash
#
# Posture Reminder — 설정한 주기마다 dorso 스타일 화면 블러 오버레이로 스트레칭을 알리는 SwiftBar 플러그인
# 오버레이는 tldev/dorso 의 Compatibility Mode 와 같은 NSVisualEffectView(behind-window blur)를 사용합니다.
#
# <swiftbar.title>자세 및 스트레칭 알림</swiftbar.title>
# <swiftbar.version>1.0</swiftbar.version>
# <swiftbar.author>Claude</swiftbar.author>
# <swiftbar.desc>설정한 주기마다 화면 블러 오버레이와 알림으로 자세 교정/스트레칭을 유도합니다.</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

CONF_DIR="$HOME/.config/posture-reminder"
INTERVAL_FILE="$CONF_DIR/interval"               # 알림 주기 (분)
LAST_RESET_FILE="$CONF_DIR/last_reset"           # 타이머 시작 시각 (epoch)
OVERLAY_SECONDS_FILE="$CONF_DIR/overlay_seconds" # 오버레이 자동 종료 (초)
PAUSED_FILE="$CONF_DIR/paused"

mkdir -p "$CONF_DIR"

interval_min()    { cat "$INTERVAL_FILE" 2>/dev/null || echo 50; }
overlay_seconds() { cat "$OVERLAY_SECONDS_FILE" 2>/dev/null || echo 12; }
last_reset()      { cat "$LAST_RESET_FILE" 2>/dev/null || echo 0; }
reset_timer()     { date +%s > "$LAST_RESET_FILE"; }

# dorso 스타일 전체 화면 블러 오버레이 (모든 디스플레이, 클릭 또는 시간 경과로 닫힘)
show_overlay() {
  local jxa
  jxa=$(cat <<'JXA'
ObjC.import('Cocoa')

function addLabel(win, text, size, bold, y, alpha) {
  var w = win.frame.size.width
  var l = $.NSTextField.labelWithString($(text))
  l.setFont(bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size))
  l.setTextColor($.NSColor.colorWithCalibratedWhiteAlpha(1, alpha))
  l.setAlignment(1)
  l.setFrame($.NSMakeRect(0, y, w, size * 1.6))
  win.contentView.addSubview(l)
}

function run(argv) {
  var seconds = parseFloat(argv[0])
  if (!(seconds > 0)) seconds = 12

  var app = $.NSApplication.sharedApplication
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)

  var tips = [
    '1. 양손 깍지 끼고 하늘 위로 기지개 켜기',
    '2. 의자 등받이를 잡고 허리 비틀기',
    '3. 턱 당기고 목 양옆으로 늘려주기'
  ]

  var screens = $.NSScreen.screens
  var windows = []
  for (var i = 0; i < screens.count; i++) {
    var frame = screens.objectAtIndex(i).frame
    var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
      frame, $.NSWindowStyleMaskBorderless, $.NSBackingStoreBuffered, false)
    win.setOpaque(false)
    win.setBackgroundColor($.NSColor.clearColor)
    win.setLevel(1000)             // 화면보호기 레벨 — 모든 앱 위에 표시
    win.setCollectionBehavior(257) // canJoinAllSpaces | fullScreenAuxiliary
    win.setAlphaValue(0)

    var w = frame.size.width, h = frame.size.height

    var blur = $.NSVisualEffectView.alloc.initWithFrame($.NSMakeRect(0, 0, w, h))
    blur.setMaterial(15)     // fullScreenUI
    blur.setBlendingMode(0)  // behindWindow — 뒤 화면을 블러
    blur.setState(1)         // active
    win.contentView.addSubview(blur)

    // 라이트 모드에서도 흰 글씨가 읽히도록 어두운 틴트를 한 겹 깐다
    var tint = $.NSBox.alloc.initWithFrame($.NSMakeRect(0, 0, w, h))
    tint.setBoxType(4)
    tint.setBorderWidth(0)
    tint.setFillColor($.NSColor.colorWithCalibratedRedGreenBlueAlpha(0, 0, 0, 0.4))
    win.contentView.addSubview(tint)

    var mid = h * 0.55
    addLabel(win, '🧘 스트레칭 타임', 46, true, mid + 40, 1.0)
    addLabel(win, '앉은 지 오래됐어요 — 허리를 펴고 몸을 풀어주세요', 22, false, mid - 20, 0.95)
    for (var t = 0; t < tips.length; t++) {
      addLabel(win, tips[t], 18, false, mid - 90 - t * 36, 0.85)
    }
    addLabel(win, '클릭하면 닫힙니다 · ' + Math.round(seconds) + '초 후 자동으로 사라집니다', 14, false, mid - 230, 0.6)

    win.orderFrontRegardless
    windows.push(win)
  }
  app.activateIgnoringOtherApps(true)

  function setAlpha(a) {
    for (var i = 0; i < windows.length; i++) windows[i].setAlphaValue(a)
  }
  function tick(sec) {
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(sec))
  }

  for (var a = 0; a <= 1.0; a += 0.1) { setAlpha(a); tick(0.02) }

  // 클릭하면 닫는다. 예전엔 0.1s 마다 pressedMouseButtons 를 폴링했는데,
  // 짧은 클릭(누름→뗌 50~150ms)이 폴링 간격 사이에 통째로 들어가면 감지되지 않아
  // "클릭해도 안 닫힘" 문제가 있었다. 전역/로컬 이벤트 모니터로 mouse-down 자체를 잡는다.
  // (모니터는 새 mouse-down 만 잡으므로, 메뉴에서 누르고 있던 클릭으로 바로 닫히지 않는다)
  var clicked = false
  var mask = (1 << 1) | (1 << 3)   // NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown
  var onClick = function(ev) { clicked = true; return ev }
  var gMon = $.NSEvent.addGlobalMonitorForEventsMatchingMaskHandler(mask, onClick)
  var lMon = $.NSEvent.addLocalMonitorForEventsMatchingMaskHandler(mask, onClick)

  // 폴백: 모니터가 동작하지 않는 환경 대비해 버튼 상태를 촘촘히(0.03s) 폴링
  var armed = false
  var deadline = $.NSDate.dateWithTimeIntervalSinceNow(seconds)
  while (!clicked && $.NSDate.date.timeIntervalSinceDate(deadline) < 0) {
    tick(0.03)
    var pressed = $.NSEvent.pressedMouseButtons !== 0
    if (!pressed) armed = true
    else if (armed) break
  }

  if (gMon) $.NSEvent.removeMonitor(gMon)
  if (lMon) $.NSEvent.removeMonitor(lMon)

  for (var a2 = 1.0; a2 >= 0; a2 -= 0.1) { setAlpha(a2); tick(0.02) }
  for (var i2 = 0; i2 < windows.length; i2++) windows[i2].close
}
JXA
)
  osascript -l JavaScript -e "$jxa" "$(overlay_seconds)"
}

notify() {
  osascript -e 'display notification "허리를 펴고 어깨를 돌려주세요. 잠시 화면이 흐려집니다." with title "🚨 자세 교정 알림" subtitle "집중 시간 완료" sound name "Glass"' >/dev/null 2>&1
}

fire() {
  reset_timer
  notify
  nohup "$0" overlay >/dev/null 2>&1 &
}

ask_number() { # $1=안내 문구, $2=기본값
  osascript -e 'text returned of (display dialog "'"$1"'" default answer "'"$2"'" with title "자세 및 스트레칭 알림" buttons {"취소", "확인"} default button "확인" cancel button "취소")' 2>/dev/null
}

# ---- 액션 처리 (메뉴 클릭 시 인자와 함께 재실행됨) ----
case "$1" in
  overlay)  show_overlay; exit 0 ;;
  show_now) fire; exit 0 ;;
  reset)    reset_timer; exit 0 ;;
  pause)    touch "$PAUSED_FILE"; exit 0 ;;
  resume)   rm -f "$PAUSED_FILE"; reset_timer; exit 0 ;;
  set_interval) echo "$2" > "$INTERVAL_FILE"; reset_timer; exit 0 ;;
  custom_interval)
    ans=$(ask_number "알림 주기를 분 단위로 입력하세요 (1–480)" "$(interval_min)")
    if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le 480 ]; then
      echo "$ans" > "$INTERVAL_FILE"
      reset_timer
    fi
    exit 0 ;;
  custom_overlay_secs)
    ans=$(ask_number "오버레이 표시 시간을 초 단위로 입력하세요 (3–120)" "$(overlay_seconds)")
    if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 3 ] && [ "$ans" -le 120 ]; then
      echo "$ans" > "$OVERLAY_SECONDS_FILE"
    fi
    exit 0 ;;
  edit) open -e "$0"; exit 0 ;;
esac

# ---- 메뉴 그리기 ----
SCRIPT="$0"
INTERVAL=$(interval_min)

[ -f "$LAST_RESET_FILE" ] || reset_timer

if [ -f "$PAUSED_FILE" ]; then
  echo ":figure.seated.side: | sfcolor=#8E8E93"
  echo "---"
  echo "자세 알림 일시정지 중 | color=#8E8E93 size=13"
  echo "---"
  echo "다시 시작 | bash=\"$SCRIPT\" param1=resume terminal=false refresh=true"
else
  NOW=$(date +%s)
  ELAPSED=$(( NOW - $(last_reset) ))
  REMAIN=$(( INTERVAL * 60 - ELAPSED ))
  if [ "$REMAIN" -le 0 ]; then
    fire
    REMAIN=$(( INTERVAL * 60 ))
  fi
  REMAIN_MIN=$(( (REMAIN + 59) / 60 ))
  COLOR="#34C759"
  [ "$REMAIN_MIN" -le 10 ] && COLOR="#F5A623"
  [ "$REMAIN_MIN" -le 5 ]  && COLOR="#FF3B30"

  echo ":figure.cooldown: ${REMAIN_MIN}분 | sfcolor=$COLOR"
  echo "---"
  echo "다음 스트레칭까지 ${REMAIN_MIN}분 남음 (주기 ${INTERVAL}분) | color=#8E8E93 size=13"
  echo "---"
  echo "지금 스트레칭 하기 🙆 | bash=\"$SCRIPT\" param1=show_now terminal=false refresh=true"
  echo "타이머 다시 시작 | bash=\"$SCRIPT\" param1=reset terminal=false refresh=true"
  echo "일시정지 | bash=\"$SCRIPT\" param1=pause terminal=false refresh=true"
fi

echo "---"
echo "추천 스트레칭 동작"
echo "--1. 양손 깍지 끼고 하늘 위로 기지개 켜기"
echo "--2. 의자 등받이를 잡고 허리 비틀기"
echo "--3. 턱 당기고 목 양옆으로 늘려주기"
echo "---"
echo "알림 주기 변경 (현재 ${INTERVAL}분)"
for m in 25 30 45 50 60 90; do
  CHECKED=""
  [ "$m" = "$INTERVAL" ] && CHECKED=" checked=true"
  echo "--${m}분 | bash=\"$SCRIPT\" param1=set_interval param2=$m terminal=false refresh=true$CHECKED"
done
echo "--직접 입력… | bash=\"$SCRIPT\" param1=custom_interval terminal=false refresh=true"
echo "Settings"
echo "--오버레이 표시 시간 변경 (현재 $(overlay_seconds)초) | bash=\"$SCRIPT\" param1=custom_overlay_secs terminal=false refresh=true"
echo "--스크립트 편집기 열기 | bash=\"$SCRIPT\" param1=edit terminal=false"
echo "--전체 새로고침 | href=swiftbar://refreshallplugins"
