# swiftbar-plugins

macOS [SwiftBar](https://github.com/swiftbar/SwiftBar) 메뉴바 플러그인 모음.

## 플러그인

### posture-reminder.1m.sh — 자세 및 스트레칭 알림

설정한 주기마다 알림 배너와 [dorso](https://github.com/tldev/dorso) 스타일 전체 화면 블러 오버레이로 스트레칭을 유도한다.

- 메뉴바에 다음 알림까지 남은 시간 카운트다운 표시 (10분 이하 주황, 5분 이하 빨강)
- 주기: 드롭다운 프리셋 25/30/45/50/60/90분 또는 직접 입력 1–480분 (기본 50분)
- 오버레이: `NSVisualEffectView` behind-window 블러, 멀티 디스플레이 지원. 스트레칭을 한 동작씩 큰 글씨 + 카운트다운으로 안내하는 **가이드 시퀀스**로 표시하며, 클릭하면 다음 동작으로 건너뛴다(마지막 동작을 넘기면 닫힘)
- 동작당 유지 시간: 각 동작을 안내하는 시간(기본 12초, 3–120초 설정 가능). 총 오버레이 시간 ≈ 동작 수 × 유지 시간
- 동작 목록: 스크립트 상단 `STRETCHES` 배열에서 편집 (메뉴 Settings → "스크립트 편집기 열기")
- 일시정지/재개, 타이머 리셋, 즉시 실행 메뉴 제공
- 설정 저장: `~/.config/posture-reminder/` (`interval`, `overlay_seconds`, `last_reset`, `paused`)

### keep-awake.sh — 잠자기 방지

macOS 내장 `caffeinate`로 맥 잠자기를 차단/해제한다. 화면만 끄고 시스템은 깨어 있게 하는 잠금 모드 지원.

## 설치

```bash
brew install swiftbar
git clone git@github.com-personal:byunginK/swiftbar-plugins.git ~/.swiftbar-plugins
```

SwiftBar 최초 실행 시 플러그인 폴더를 `~/.swiftbar-plugins`로 지정한다.
