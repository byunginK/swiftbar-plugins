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

# 전체 화면 블러 오버레이 — 스트레칭을 한 동작씩 카운트다운으로 안내하는 가이드 시퀀스
# 클릭하면 다음 동작으로 건너뛰고, 마지막 동작을 넘기면 닫힌다.
show_overlay() {
  local jxa
  jxa=$(cat <<'JXA'
ObjC.import('Cocoa')

// 앉아서 하는 사무직 스트레칭 시퀀스 — 근거 기반(ACSM 2011·Mayo Clinic·물리치료 가이드)
// t=동작명, s=수행 방법·주의, d=안내 시간(초). 통증 아닌 긴장까지 · 반동 금지 · 목 과신전/과회전 회피.
var STRETCHES = [
  { t: '턱 당기기 (친 턱)',   s: '턱을 뒤로 당겨 이중 턱 만들기 · 3~5초씩 천천히 반복 (아래로 숙이지 않기)', d: 20 },
  { t: '목 옆으로 늘리기',     s: '손으로 머리를 옆으로 지그시, 반대 어깨는 내리기 · 좌우 각 15초 (당기지 말고 긴장까지)', d: 30 },
  { t: '견갑거근 늘리기',      s: '어깨 내리고 고개를 반대로 돌려 겨드랑이 쪽 내려다보기 · 좌우 각 15초', d: 30 },
  { t: '가슴 활짝 펴기',       s: '양손을 등 뒤로 깍지 껴 가슴을 열기 · 어깨 아프면 범위 줄이기', d: 25 },
  { t: '앉은 흉추 젖히기',     s: '등받이에 윗등 대고 손으로 머리 받쳐 뒤로 젖혔다 돌아오기 · 천천히 5~8회', d: 20 }
]

function makeLabel(win, size, bold, y, alpha) {
  var w = win.frame.size.width
  var l = $.NSTextField.labelWithString($(''))
  l.setFont(bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size))
  l.setTextColor($.NSColor.colorWithCalibratedWhiteAlpha(1, alpha))
  l.setAlignment(1)
  l.setFrame($.NSMakeRect(0, y, w, size * 1.6))
  win.contentView.addSubview(l)
  return l
}

function run(argv) {
  var hold = parseFloat(argv[0])   // 동작당 유지 시간(초)
  if (!(hold > 0)) hold = 12

  var app = $.NSApplication.sharedApplication
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)

  var screens = $.NSScreen.screens
  var wins = []
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
    tint.setFillColor($.NSColor.colorWithCalibratedRedGreenBlueAlpha(0, 0, 0, 0.45))
    win.contentView.addSubview(tint)

    var cy = h / 2
    wins.push({
      win:   win,
      prog:  makeLabel(win, 26, true,  cy + 150, 0.85), // 진행 (i/N)
      instr: makeLabel(win, 40, true,  cy + 30,  1.0),  // 동작 지시
      sub:   makeLabel(win, 22, false, cy - 40,  0.9),  // 보조 설명
      count: makeLabel(win, 54, true,  cy - 150, 1.0),  // 카운트다운
      hint:  makeLabel(win, 15, false, cy - 220, 0.6)   // 진행 점 + 안내
    })
    win.orderFrontRegardless
  }
  app.activateIgnoringOtherApps(true)

  function setAlpha(a) { for (var i = 0; i < wins.length; i++) wins[i].win.setAlphaValue(a) }
  function tick(sec) { $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(sec)) }

  function render(idx) {
    var s = STRETCHES[idx]
    var dots = ''
    for (var d = 0; d < STRETCHES.length; d++) dots += (d <= idx ? '●' : '○')
    var prog = '🧘 스트레칭  ' + (idx + 1) + ' / ' + STRETCHES.length
    for (var i = 0; i < wins.length; i++) {
      wins[i].prog.setStringValue($(prog))
      wins[i].instr.setStringValue($(s.t))
      wins[i].sub.setStringValue($(s.s))
      wins[i].hint.setStringValue($(dots + '      클릭하면 건너뛰기'))
    }
  }
  function setCount(sec) {
    var txt = '⟳  ' + sec + '초'
    for (var i = 0; i < wins.length; i++) wins[i].count.setStringValue($(txt))
  }

  for (var a = 0; a <= 1.0; a += 0.1) { setAlpha(a); tick(0.02) }

  // 클릭하면 다음 동작으로 건너뛴다. osascript 는 앱 이벤트 루프를 돌지 않으므로
  // 이벤트 큐를 직접 펌프(nextEvent)해서 mouse-down 을 잡고, pressedMouseButtons
  // 폴링은 트랙패드 탭처럼 눌림이 순간적인 클릭을 위한 폴백으로 둔다.
  var downMask = (1 << 1) | (1 << 3)   // NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown
  var armed = false                    // 오버레이가 뜨기 전부터 눌려 있던 버튼은 무시
  for (var idx = 0; idx < STRETCHES.length; idx++) {
    render(idx)
    var remaining = Math.round(STRETCHES[idx].d || hold)
    var skip = false
    while (remaining > 0 && !skip) {
      setCount(remaining)
      var sliceEnd = $.NSDate.dateWithTimeIntervalSinceNow(1)
      while ($.NSDate.date.timeIntervalSinceDate(sliceEnd) < 0) {
        var ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
          downMask, $.NSDate.dateWithTimeIntervalSinceNow(0.05), $.NSDefaultRunLoopMode, true)
        if (ev && !ev.isNil()) { skip = true; break }
        var pressed = $.NSEvent.pressedMouseButtons !== 0
        if (!pressed) armed = true
        else if (armed) { skip = true; break }
      }
      remaining -= 1
    }
  }

  for (var a2 = 1.0; a2 >= 0; a2 -= 0.1) { setAlpha(a2); tick(0.02) }
  for (var i2 = 0; i2 < wins.length; i2++) wins[i2].win.close
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
  overlay)  show_overlay "$2"; exit 0 ;;
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
    ans=$(ask_number "동작당 유지 시간을 초 단위로 입력하세요 (3–120)" "$(overlay_seconds)")
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
echo "알림 주기 변경 (현재 ${INTERVAL}분)"
for m in 25 30 45 50 60 90; do
  CHECKED=""
  [ "$m" = "$INTERVAL" ] && CHECKED=" checked=true"
  echo "--${m}분 | bash=\"$SCRIPT\" param1=set_interval param2=$m terminal=false refresh=true$CHECKED"
done
echo "--직접 입력… | bash=\"$SCRIPT\" param1=custom_interval terminal=false refresh=true"
echo "Settings"
echo "--동작당 유지 시간 변경 (현재 $(overlay_seconds)초) | bash=\"$SCRIPT\" param1=custom_overlay_secs terminal=false refresh=true"
echo "--스크립트 편집기 열기 | bash=\"$SCRIPT\" param1=edit terminal=false"
echo "--전체 새로고침 | href=swiftbar://refreshallplugins"
