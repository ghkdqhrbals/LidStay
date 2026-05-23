# LidStay PRD

## 1. 제품 개요

LidStay는 macOS 메뉴바에서 Mac을 일정 시간 동안 켜두도록 제어하는 경량 유틸리티다. 사용자는 메뉴바 아이콘만 보고 현재 동작 상태를 알 수 있고, 메뉴에서 즉시 세션을 시작/중지하거나 시간을 선택할 수 있다.

핵심 방향은 KeepingYouAwake처럼 단순한 메뉴바 제어를 유지하면서, 배터리 보호와 작업 생명주기 기반 세션을 더 명확하게 제공하는 것이다. LidStay는 공개 macOS 전원 API만 사용하며, 디스플레이 잠자기는 막지 않는다.

## 2. 목표

- 메뉴바에서 Mac 켜두기 상태를 즉시 확인할 수 있어야 한다.
- 사용자가 세션 시간을 빠르게 선택할 수 있어야 한다.
- 기본값은 계속 켜두기 세션이어야 한다.
- 전원 연결 여부와 배터리 잔량을 고려해 가능한 절전 동작을 유지해야 한다.
- 디스플레이에는 부담을 주지 않도록 화면 켜짐 유지 기능은 제공하지 않는다.
- 바이브코더가 터미널에서 개발 서버 실행과 함께 사용할 수 있도록 CLI를 제공한다.
- 다운로드, 백업, 파일 전송, 원격 접속, 긴 export 작업처럼 사용자가 자리를 비워도 끝까지 완료되어야 하는 작업을 보호한다.
- 설치와 배포는 GitHub Release, GitHub Pages, Homebrew cask, notarized zip 흐름을 지원한다.
- 일반 사용자는 zip을 풀고 앱을 실행하는 것만으로 CLI까지 설치할 수 있어야 한다.

## 3. 비목표

- 비공개 API, 커널 확장, 관리자 권한 helper, LaunchDaemon 사용
- 디스플레이 잠자기 방지
- 화면 밝기 제어
- 화면 보호기 제어
- 커서 자동 이동이나 사용자 활동 위장 기능
- 모든 Mac 모델과 모든 덮개 닫힘 조건에서 동작 강제 보장
- 복잡한 트리거 빌더나 Amphetamine 수준의 고급 자동화

## 4. 대상 사용자

- MacBook을 닫거나 자리를 비워도 개발 서버, 다운로드, 장시간 작업을 유지하고 싶은 사용자
- `npm run dev`, `pnpm dev`, 로컬 서버 실행 중 Mac이 잠들지 않게 하고 싶은 바이브코더
- 대용량 다운로드, 백업, 클라우드 업로드, 원격 SSH 세션, 영상/코드 export가 끝나기 전까지 Mac을 켜두고 싶은 사용자
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
  - 계속 켜두기: 열린 눈꺼풀 안에 무한 표시
- 앱 아이콘:
  - 동공 없는 눈꺼풀 시그니처 아이콘

### 6.2 세션 제어

- `Mac 켜두기`로 세션 시작
- `Mac 켜두기 중지`로 세션 종료
- 시간 선택:
  - `계속 켜두기`
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
  - 예: `켜두는 중 · 계속 켜두기`
  - 예: `잠깐 중지 · 배터리 20%라서 잠깐 중지했습니다.`

### 6.4 전원 조건

- 기본 동작은 전원 연결 시에만 Mac 켜두기
- 옵션에서 배터리 사용 중에도 Mac 켜두기 허용 가능
- 옵션 창은 탭 없이 한 화면에 정렬된 설정 목록으로 제공한다.
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
- Sparkle 자동 업데이트 설정은 Sparkle의 `SPUUpdater`가 관리하는 user defaults를 사용한다.
- `automaticallyChecksForUpdates`, `automaticallyDownloadsUpdates` 값을 별도 앱 설정으로 중복 저장하지 않는다.

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
- 옵션은 한 화면에서 같은 라벨 폭과 같은 컨트롤 시작점을 유지한다.
- 고급 기능은 기본 메뉴를 복잡하게 만들지 않고 CLI나 별도 문서에서 제공한다.

## 10. CLI

- 설치 시 `lidstay` 명령어를 함께 제공한다.
- 앱 번들 안에 CLI를 포함하고, 앱 첫 실행 시 `/usr/local/bin/lidstay`에 자동 설치 또는 업데이트한다.
- `/usr/local/bin`에 쓰기 권한이 없으면 macOS 관리자 권한 요청을 통해 설치한다.
- 지원 명령:
  - `lidstay on 2h`
  - `lidstay on until-exit npm run dev`
  - `lidstay off`
  - `lidstay status`
- `until-exit`은 지정한 프로세스가 종료되면 자동으로 `off` 명령을 보낸다.
- CLI는 앱의 기존 power assertion 로직을 사용해야 하며 별도 전원 유지 구현을 만들지 않는다.

## 11. 제품 방향

- KeepingYouAwake의 장점인 한 번 클릭, 미리 정한 시간, 낮은 배터리에서 자동 중지, 가벼운 메뉴바 앱 방향을 유지한다.
- LidStay의 차별점은 “작업이 끝날 때까지 켜두고, 끝나면 원래 상태로 돌아가는 것”이다.
- 바이브코딩 외에도 다운로드, 백업, 파일 전송, 원격 접속, 긴 export 작업을 명확한 사용 사례로 다룬다.
- 커서 움직이기, 화면 보호기 우회, 사용 중인 척하는 기능은 제품 신뢰성과 방향성 때문에 제공하지 않는다.

## 12. 배포 요구사항

### 12.1 GitHub

- 저장소: `https://github.com/ghkdqhrbals/LidStay`
- 최신 릴리스: `https://github.com/ghkdqhrbals/LidStay/releases/latest`

### 12.2 설치 페이지

- GitHub Pages용 설치 페이지:
  - `docs/index.html`
- 사용자는 Release 페이지에서 `LidStay.zip`을 내려받을 수 있어야 한다.
- 사용자가 zip을 풀고 `LidStay.app`을 실행하면 앱이 포함된 CLI를 `/usr/local/bin/lidstay`에 설치한다.
- `LidStay.pkg`는 앱과 CLI를 함께 설치하는 대체 배포물로 유지한다.

### 12.3 자동 업데이트

- 직접 배포 자동 업데이트는 Sparkle 2를 사용한다.
- 메뉴에는 `업데이트 확인`을 제공한다.
- 옵션 창에는 다음 항목을 제공한다.
  - `자동 업데이트`: 새 버전 자동 확인
  - `자동 설치`: 가능한 경우 자동 다운로드/설치
- 앱 Info.plist에는 다음 Sparkle 키를 포함한다.
  - `SUFeedURL`
  - `SUPublicEDKey`
  - `SUEnableAutomaticChecks`
  - `SUAutomaticallyUpdate`
  - `SUVerifyUpdateBeforeExtraction`
- Sparkle 공개키가 실제 값으로 주입되지 않은 개발 빌드에서는 업데이트 기능을 시작하지 않고 `릴리스 설정 필요` 상태로 표시한다.
- appcast 기본 URL:
  - `https://github.com/ghkdqhrbals/LidStay/releases/latest/download/appcast.xml`
- 릴리스 시 `packaging/generate-appcast.sh`로 appcast를 생성한다.
- GitHub Release에는 사용자용 `LidStay.zip`, Sparkle용 버전 아카이브, `appcast.xml`을 업로드한다.

### 12.4 Homebrew

- 로컬 cask 설치 스크립트 제공:
  - `packaging/install-with-brew.sh`
- cask 정의:
  - `packaging/homebrew/lidstay.rb`
- cask는 `LidStay.app`과 `lidstay` CLI를 함께 설치한다.

### 12.5 Notarized Zip

- 직접 배포용 zip은 Developer ID Application 인증서로 서명해야 한다.
- Apple notarization 완료 후 stapling된 앱을 zip으로 패키징한다.
- Sparkle 자동 업데이트용 public key는 프로젝트 기본 빌드 설정에 포함한다.
- 스크립트:
  - `packaging/build-notarized-zip.sh`

### 12.6 Notarized Pkg

- 일반 사용자용 기본 배포물은 pkg 설치 파일이다.
- pkg는 앱과 CLI를 함께 설치한다.
- pkg 서명에는 `Developer ID Installer` 인증서가 필요하다.
- 스크립트:
  - `packaging/build-pkg.sh`
  - `packaging/build-notarized-pkg.sh`

### 12.7 GitHub Actions Release

- `.github/workflows/release.yml`에서 `v*` 태그 push 또는 수동 실행으로 릴리스를 생성한다.
- Actions는 임시 Keychain을 만들고 GitHub Secrets의 Developer ID `.p12` 인증서를 import한다.
- Actions는 App Store Connect API key로 `lidstay-notary` notarytool profile을 만든다.
- Actions는 다음 산출물을 생성해 GitHub Release에 업로드한다.
  - `LidStay.zip`
  - `appcast.xml`
  - Sparkle 업데이트용 버전 zip
- Developer ID Installer 인증서 secret이 있으면 `LidStay.pkg`도 함께 생성해 업로드한다.
- 필수 GitHub Secrets:
  - `APP_STORE_CONNECT_API_KEY_BASE64`
  - `APP_STORE_CONNECT_KEY_ID`
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
  - `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
  - `SPARKLE_PRIVATE_ED_KEY`
- pkg 배포용 선택 GitHub Secrets:
  - `DEVELOPER_ID_INSTALLER_CERTIFICATE_BASE64`
  - `DEVELOPER_ID_INSTALLER_CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD`는 Actions 런타임에서 임시 생성하며 secret으로 받지 않는다.

## 13. Apple Developer 설정

### 13.1 App ID

Apple Developer의 `Certificates, Identifiers & Profiles`에서 다음 App ID를 생성한다.

- Platform: macOS
- Type: App IDs
- Bundle ID: Explicit
- Identifier: `com.ghkdqhrbals.LidStay`
- Capabilities: 선택 없음

현재 기능 기준으로 iCloud, Push Notifications, App Groups, Sign in with Apple 등은 필요하지 않다.

### 13.2 인증서

직접 배포에는 다음 인증서가 필요하다.

- `Developer ID Application`
- `Developer ID Installer`
- 기본 인증서 이름:
  - `Developer ID Application: gyumin hwangbo (4CL25TC734)`
  - `Developer ID Installer: gyumin hwangbo (4CL25TC734)`
- 기본 notarization profile:
  - `lidstay-notary`

Mac App Store 배포를 진행할 경우 별도 인증서와 App Store Connect 앱 레코드가 필요하다.

## 14. 테스트 계획

### 14.1 기본 실행

- 앱 실행 시 메뉴바 아이콘이 표시되어야 한다.
- Dock 아이콘은 표시되지 않아야 한다.
- 메뉴 클릭 시 네이티브 메뉴가 열려야 한다.

### 14.2 세션

- `Mac 켜두기` 클릭 시 assertion이 생성되어야 한다.
- `Mac 켜두기 중지` 클릭 시 assertion이 해제되어야 한다.
- 시간 선택 시 해당 시간으로 세션이 시작되어야 한다.
- 꺼진 상태에서 시간 선택 시 자동으로 켜져야 한다.
- 직접 입력 시간이 유효하지 않으면 세션이 시작되지 않아야 한다.

### 14.3 상태 표시

- 켜두는 중이면 작은 초록 점이 표시되어야 한다.
- 잠깐 중지 상태이면 작은 주황 점이 표시되어야 한다.
- 꺼짐이면 작은 회색 점이 표시되어야 한다.
- 실패 시 작은 빨간 점이 표시되어야 한다.

### 14.4 전원 조건

- AC 전원에서 세션이 켜져 있으면 assertion이 활성화되어야 한다.
- 배터리에서 `배터리에서도 켜두기`가 꺼져 있으면 assertion이 비활성화되어야 한다.
- 배터리에서 `배터리에서도 켜두기`가 켜져 있으면 assertion 생성을 시도해야 한다.
- 배터리 잔량이 설정한 퍼센트 이하이면 assertion이 해제되어야 한다.
- 전원 연결/해제 시 상태가 자동 갱신되어야 한다.

### 14.5 자동 업데이트

- Sparkle 패키지가 앱에 링크되어야 한다.
- `Info.plist`에 `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`가 포함되어야 한다.
- Sparkle 공개키가 placeholder이면 업데이트 컨트롤러가 시작되지 않아야 한다.
- `업데이트 확인`은 Sparkle 설정이 완료된 경우 Sparkle 확인 UI를 열어야 한다.
- `자동 업데이트` 옵션은 Sparkle의 `automaticallyChecksForUpdates` 값을 바꿔야 한다.
- `자동 설치` 옵션은 Sparkle의 `automaticallyDownloadsUpdates` 값을 바꿔야 한다.

### 14.6 종료

- 앱 종료 시 assertion이 남지 않아야 한다.
- 세션 타이머가 정리되어야 한다.

### 14.7 디스플레이

- 디스플레이 잠자기는 계속 허용되어야 한다.
- 앱이 화면 밝기나 화면 보호기 설정을 바꾸지 않아야 한다.

## 15. 향후 후보 기능

현재 제품 방향을 해치지 않는 범위에서만 검토한다.

- 특정 앱 실행 중 자동으로 Mac 켜두기
- 로컬 서버 포트 감지 시 자동으로 Mac 켜두기
- 다운로드/업로드 중 자동 유지
- 외장 디스크 연결 중 자동 유지
- 세션 종료 알림

모든 후보 기능은 메뉴 복잡도를 크게 늘리지 않는 방식으로만 추가한다.
