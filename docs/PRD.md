# LidStay PRD

## 1. 제품 개요

LidStay는 macOS 메뉴바에서 Mac을 일정 시간 동안 켜두도록 제어하는 경량 유틸리티다. 사용자는 메뉴바 아이콘만 보고 현재 동작 상태를 알 수 있고, 메뉴에서 즉시 세션을 시작/중지하거나 시간을 선택할 수 있다.

핵심 방향은 Amphetamine처럼 강력한 전원 유지 기능을 제공하되, 설정과 표현은 훨씬 단순하게 유지하는 것이다. LidStay는 공개 macOS 전원 API만 사용하며, 디스플레이 잠자기는 막지 않는다.

## 2. 목표

- 메뉴바에서 Mac 켜두기 상태를 즉시 확인할 수 있어야 한다.
- 사용자가 세션 시간을 빠르게 선택할 수 있어야 한다.
- 기본값은 무제한 세션이어야 한다.
- 전원 연결 여부와 배터리 잔량을 고려해 가능한 절전 동작을 유지해야 한다.
- 디스플레이에는 부담을 주지 않도록 화면 켜짐 유지 기능은 제공하지 않는다.
- 설치와 배포는 GitHub Release, GitHub Pages, Homebrew cask, notarized zip 흐름을 지원한다.

## 3. 비목표

- 비공개 API, 커널 확장, 관리자 권한 helper, LaunchDaemon 사용
- 디스플레이 잠자기 방지
- 화면 밝기 제어
- 화면 보호기 제어
- 모든 Mac 모델과 모든 덮개 닫힘 조건에서 동작 강제 보장
- 복잡한 트리거 빌더나 Amphetamine 수준의 고급 자동화

## 4. 대상 사용자

- MacBook을 닫거나 자리를 비워도 개발 서버, 다운로드, 장시간 작업을 유지하고 싶은 사용자
- 복잡한 전원 앱보다 단순한 메뉴바 제어를 원하는 사용자
- 배터리 보호와 디스플레이 잠자기를 유지하고 싶은 사용자

## 5. 핵심 사용자 시나리오

1. 사용자는 메뉴바에서 LidStay 아이콘을 클릭한다.
2. `Mac 켜두기`를 누르거나 시간을 먼저 선택한다.
3. 세션이 시작되면 메뉴바 아이콘이 켜진 상태로 바뀐다.
4. 메뉴 상단에는 작은 상태 점과 현재 세션 상태가 표시된다.
5. 세션 시간이 끝나거나 사용자가 중지하면 전원 assertion이 해제된다.
6. 배터리 제한 조건에 걸리면 세션은 켜져 있어도 실제 전원 유지는 잠깐 중지된다.

## 6. 구현된 기능

### 6.1 메뉴바 앱

- SwiftUI `MenuBarExtra` 기반 macOS 메뉴바 앱
- Dock 아이콘 없이 실행
- 메뉴바 아이콘 상태:
  - 꺼짐: 닫힌 눈꺼풀 아이콘
  - 켜짐: 열린 눈꺼풀 아이콘
  - 무제한: 열린 눈꺼풀 안에 무한 표시
- 앱 아이콘:
  - 동공 없는 눈꺼풀 시그니처 아이콘

### 6.2 세션 제어

- `Mac 켜두기`로 세션 시작
- `Mac 켜두기 중지`로 세션 종료
- 시간 선택:
  - `무제한`
  - `30분`
  - `1시간`
  - `2시간`
  - `직접 입력`
- 꺼진 상태에서 시간을 선택하면 자동으로 세션 시작
- 세션 종료 시 power assertion 해제

### 6.3 상태 표시

- 메뉴 상단에 현재 상태를 간단히 표시
- 상태 점:
  - 초록: 켜두는 중
  - 주황: 잠깐 중지
  - 회색: 꺼짐
  - 빨강: 실패
- 상태 점은 emoji가 아니라 작은 PNG asset으로 표시한다.
- 상단 문구는 이유 설명 없이 간단히 표시한다.
  - 예: `켜두는 중 · 무제한`
  - 예: `잠깐 중지 · 배터리 20%라서 잠깐 중지했습니다.`

### 6.4 전원 조건

- 기본 동작은 전원 연결 시에만 Mac 켜두기
- 옵션에서 배터리 사용 중에도 Mac 켜두기 허용 가능
- 전원 소스 변경 감지
- 전원 연결/해제 시 assertion 자동 갱신

### 6.5 배터리 자동 중지

- 배터리 퍼센트 이하 자동 중지 옵션 제공
- 기본값: 20%
- 선택값:
  - 10%
  - 15%
  - 20%
  - 30%
  - 40%
  - 직접 입력
- 설정한 퍼센트 이하에서는 assertion을 해제하고 `잠깐 중지` 상태로 표시

### 6.6 로그인 시 자동 실행

- `로그인 시 자동 실행` 옵션 제공
- LaunchAgent 기반 구현
- LaunchAgent label:
  - `com.ghkdqhrbals.LidStay.loginitem`

### 6.7 언어

- 한국어/영어 전환 지원
- 기본 언어는 한국어

### 6.8 정보 창

- 앱 이름과 핵심 동작 설명 표시
- 공개 macOS 전원 API 사용 명시
- 디스플레이 잠자기 허용 명시
- 배터리 자동 중지 설명 표시
- 연락처:
  - `ghkdqhrbals@naver.com`
- 링크:
  - GitHub
  - Releases

## 7. 시스템 구현

### 7.1 주요 컴포넌트

- `AppState`
  - UI 상태, 세션 상태, 설정, assertion 상태 연결
  - `UserDefaults` 저장/복원
  - 세션 타이머 관리
- `PowerAssertionController`
  - `IOPMAssertionCreateWithName`으로 system idle sleep 방지 assertion 생성
  - off, 세션 종료, 앱 종료 시 assertion release
- `PowerSourceMonitor`
  - IOKit power source 변경 감지
  - AC/배터리/unknown 상태와 배터리 퍼센트 제공
- `MenuBarView`
  - 메뉴바 메뉴 구성
  - 세션, 시간, 전원, 배터리, 자동 실행, 언어, 정보, 종료 UI 제공
- `AboutView`
  - 정보 창 UI
- `Tools/generate_icons.swift`
  - 앱 아이콘, 메뉴바 아이콘, 상태 점 asset 생성

### 7.2 저장 설정

`UserDefaults`에 저장되는 값:

- `isKeepAwakeEnabled`
- `allowOnBattery`
- `durationMinutesText`
- `selectedDurationID`
- `language`
- `launchAtLoginEnabled`
- `autoPauseOnLowBattery`
- `lowBatteryLimitText`

### 7.3 Bundle ID

- Bundle ID: `com.ghkdqhrbals.LidStay`
- Team ID: `4CL25TC734`
- Debug 빌드는 로컬 실행용 ad-hoc 서명 유지
- Release 빌드는 Developer ID 배포 흐름을 기준으로 설정

## 8. 전원 동작 요구사항

- 활성 세션에서 조건이 맞으면 system idle sleep assertion을 생성한다.
- 디스플레이 sleep assertion은 생성하지 않는다.
- 배터리 사용이 허용되지 않았고 전원이 빠지면 assertion을 해제한다.
- 배터리 사용이 허용되어도 설정한 배터리 퍼센트 이하이면 assertion을 해제한다.
- 앱 종료 시 assertion을 반드시 해제한다.
- 세션 시간이 만료되면 assertion을 해제하고 off 상태로 전환한다.

## 9. UI 문구 원칙

- 사용자가 바로 이해할 수 있는 문구를 사용한다.
- `blocking`, `assertion` 같은 내부 구현 용어는 사용자 UI에 노출하지 않는다.
- `Keep Awake`보다 `Mac 켜두기`, `켜두는 중`, `잠깐 중지`를 우선 사용한다.
- `정보...`처럼 불필요한 말줄임표는 사용하지 않는다.
- 상태 설명은 짧게 유지하고, 이유 설명은 필요한 경우에만 제한적으로 보여준다.

## 10. 배포 요구사항

### 10.1 GitHub

- 저장소: `https://github.com/ghkdqhrbals/LidStay`
- 최신 릴리스: `https://github.com/ghkdqhrbals/LidStay/releases/latest`

### 10.2 설치 페이지

- GitHub Pages용 설치 페이지:
  - `docs/index.html`
- 사용자는 Release 페이지에서 `LidStay.zip`을 내려받을 수 있어야 한다.

### 10.3 Homebrew

- 로컬 cask 설치 스크립트 제공:
  - `packaging/install-with-brew.sh`
- cask 정의:
  - `packaging/homebrew/lidstay.rb`

### 10.4 Notarized Zip

- 직접 배포용 zip은 Developer ID Application 인증서로 서명해야 한다.
- Apple notarization 완료 후 stapling된 앱을 zip으로 패키징한다.
- 스크립트:
  - `packaging/build-notarized-zip.sh`

## 11. Apple Developer 설정

### 11.1 App ID

Apple Developer의 `Certificates, Identifiers & Profiles`에서 다음 App ID를 생성한다.

- Platform: macOS
- Type: App IDs
- Bundle ID: Explicit
- Identifier: `com.ghkdqhrbals.LidStay`
- Capabilities: 선택 없음

현재 기능 기준으로 iCloud, Push Notifications, App Groups, Sign in with Apple 등은 필요하지 않다.

### 11.2 인증서

직접 배포에는 다음 인증서가 필요하다.

- `Developer ID Application`

Mac App Store 배포를 진행할 경우 별도 인증서와 App Store Connect 앱 레코드가 필요하다.

## 12. 테스트 계획

### 12.1 기본 실행

- 앱 실행 시 메뉴바 아이콘이 표시되어야 한다.
- Dock 아이콘은 표시되지 않아야 한다.
- 메뉴 클릭 시 네이티브 메뉴가 열려야 한다.

### 12.2 세션

- `Mac 켜두기` 클릭 시 assertion이 생성되어야 한다.
- `Mac 켜두기 중지` 클릭 시 assertion이 해제되어야 한다.
- 시간 선택 시 해당 시간으로 세션이 시작되어야 한다.
- 꺼진 상태에서 시간 선택 시 자동으로 켜져야 한다.
- 직접 입력 시간이 유효하지 않으면 세션이 시작되지 않아야 한다.

### 12.3 상태 표시

- 켜두는 중이면 작은 초록 점이 표시되어야 한다.
- 잠깐 중지 상태이면 작은 주황 점이 표시되어야 한다.
- 꺼짐이면 작은 회색 점이 표시되어야 한다.
- 실패 시 작은 빨간 점이 표시되어야 한다.

### 12.4 전원 조건

- AC 전원에서 세션이 켜져 있으면 assertion이 활성화되어야 한다.
- 배터리에서 `배터리에서도 켜두기`가 꺼져 있으면 assertion이 비활성화되어야 한다.
- 배터리에서 `배터리에서도 켜두기`가 켜져 있으면 assertion 생성을 시도해야 한다.
- 배터리 잔량이 설정한 퍼센트 이하이면 assertion이 해제되어야 한다.
- 전원 연결/해제 시 상태가 자동 갱신되어야 한다.

### 12.5 종료

- 앱 종료 시 assertion이 남지 않아야 한다.
- 세션 타이머가 정리되어야 한다.

### 12.6 디스플레이

- 디스플레이 잠자기는 계속 허용되어야 한다.
- 앱이 화면 밝기나 화면 보호기 설정을 바꾸지 않아야 한다.

## 13. 향후 후보 기능

현재 제품 방향을 해치지 않는 범위에서만 검토한다.

- 특정 앱 실행 중 자동으로 Mac 켜두기
- 로컬 서버 포트 감지 시 자동으로 Mac 켜두기
- 다운로드/업로드 중 자동 유지
- 외장 디스크 연결 중 자동 유지
- 세션 종료 알림

모든 후보 기능은 메뉴 복잡도를 크게 늘리지 않는 방식으로만 추가한다.
