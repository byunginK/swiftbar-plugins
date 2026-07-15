# swiftbar-plugins

macOS [SwiftBar](https://github.com/swiftbar/SwiftBar) 메뉴바 플러그인 모음.

## 플러그인

### posture-reminder.1m.sh — 자세 및 스트레칭 알림

설정한 주기마다 알림 배너와 [dorso](https://github.com/tldev/dorso) 스타일 전체 화면 블러 오버레이로 스트레칭을 유도한다.

- 메뉴바에 다음 알림까지 남은 시간 카운트다운 표시 (10분 이하 주황, 5분 이하 빨강)
- 주기: 드롭다운 프리셋 25/30/45/50/60/90분 또는 직접 입력 1–480분 (기본 50분)
- 오버레이: `NSVisualEffectView` behind-window 블러, 멀티 디스플레이 지원, 클릭 또는 지정 시간(기본 12초, 3–120초 설정 가능) 경과 시 닫힘
- 스트레칭 GIF: `~/.config/posture-reminder/stretches/`에 `.gif`를 넣으면 텍스트 팁 대신 GIF를 중앙에 재생하고, 오버레이가 뜰 때마다 파일을 하나씩 순환 표시한다 (메뉴 Settings → "스트레칭 GIF 폴더 열기"). GIF가 없으면 기본 텍스트 팁으로 폴백
- 추천 스트레칭 동작 메뉴: 폴더의 GIF 목록을 서브메뉴로 보여주고, 항목을 클릭하면 해당 동작의 오버레이를 즉시 미리보기
- 일시정지/재개, 타이머 리셋, 즉시 실행 메뉴 제공
- 설정 저장: `~/.config/posture-reminder/` (`interval`, `overlay_seconds`, `last_reset`, `paused`, `stretch_index`) · GIF 폴더 `stretches/`

### keep-awake.sh — 잠자기 방지

macOS 내장 `caffeinate`로 맥 잠자기를 차단/해제한다. 화면만 끄고 시스템은 깨어 있게 하는 잠금 모드 지원.

## 설치

```bash
brew install swiftbar
git clone git@github.com-personal:byunginK/swiftbar-plugins.git ~/.swiftbar-plugins
```

SwiftBar 최초 실행 시 플러그인 폴더를 `~/.swiftbar-plugins`로 지정한다.
