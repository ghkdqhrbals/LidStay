import SwiftUI

struct AboutView: View {
    let language: AppLanguage

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.1"
        return language == .korean ? "버전 \(version)" : "Version \(version)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("LidStay")
                        .font(.title2.weight(.semibold))
                    Text(language == .korean ? "시간을 고르고 Mac을 깨어있게 유지합니다." : "Choose a time and keep your Mac awake.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label(language == .korean ? "공개 macOS 전원 API로 Mac을 깨어있게 유지합니다." : "Uses public macOS power APIs to keep your Mac awake.", systemImage: "bolt.circle")
                Label(language == .korean ? "디스플레이 잠자기는 그대로 허용합니다." : "Display sleep remains allowed.", systemImage: "display")
                Label(language == .korean ? "간단한 시간 선택과 직접 분 입력을 제공합니다." : "Offers simple time choices and direct minute entry.", systemImage: "timer")
                Label(language == .korean ? "설정한 배터리 퍼센트 이하에서는 자동으로 잠깐 중지합니다." : "Automatically pauses below your chosen battery percentage.", systemImage: "battery.25")
            }
            .labelStyle(.titleAndIcon)

            VStack(alignment: .leading, spacing: 8) {
                Text(language == .korean ? "연락처" : "Contact")
                    .font(.headline)
                Link("ghkdqhrbals@naver.com", destination: URL(string: "mailto:ghkdqhrbals@naver.com")!)
                Link("GitHub", destination: URL(string: "https://github.com/ghkdqhrbals/LidStay")!)
                Link("Releases", destination: URL(string: "https://github.com/ghkdqhrbals/LidStay/releases/latest")!)
            }

            Text(language == .korean ? "덮개를 닫았을 때의 동작은 Mac 모델, 전원 상태, macOS 정책에 따라 달라질 수 있습니다. LidStay는 비공개 API, 커널 확장, 관리자 helper를 사용하지 않습니다." : "Closed-lid behavior can still depend on Mac model, power source, and macOS policy. LidStay does not use private APIs, kernel extensions, or privileged helpers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Text(versionText)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(language == .korean ? "완료" : "Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 410)
    }
}
