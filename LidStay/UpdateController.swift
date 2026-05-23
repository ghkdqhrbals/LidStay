import AppKit
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class UpdateController: NSObject, ObservableObject {
    static let shared = UpdateController()

    @Published private(set) var isConfigured = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false

    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []
    #endif

    override init() {
        #if canImport(Sparkle)
        let configured = Self.hasUsableSparkleConfiguration
        isConfigured = configured
        updaterController = configured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        #endif

        super.init()

        #if canImport(Sparkle)
        if let updater = updaterController?.updater {
            sync(from: updater)
            observe(updater)
        }
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        guard isConfigured else {
            openReleasePage()
            return
        }

        updaterController?.checkForUpdates(nil)
        #else
        openReleasePage()
        #endif
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        #if canImport(Sparkle)
        guard let updater = updaterController?.updater else {
            return
        }

        updater.automaticallyChecksForUpdates = enabled
        sync(from: updater)
        #endif
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        #if canImport(Sparkle)
        guard let updater = updaterController?.updater, updater.allowsAutomaticUpdates else {
            return
        }

        updater.automaticallyDownloadsUpdates = enabled
        sync(from: updater)
        #endif
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        #if canImport(Sparkle)
        guard let updater = updaterController?.updater else {
            return
        }

        if enabled {
            updater.automaticallyChecksForUpdates = true
            if updater.allowsAutomaticUpdates {
                updater.automaticallyDownloadsUpdates = true
            }
        } else {
            if updater.allowsAutomaticUpdates {
                updater.automaticallyDownloadsUpdates = false
            }
            updater.automaticallyChecksForUpdates = false
        }
        sync(from: updater)
        #endif
    }

    var automaticUpdatesEnabled: Bool {
        automaticallyChecksForUpdates && automaticallyDownloadsUpdates
    }

    func statusTitle(language: AppLanguage) -> String {
        if !isConfigured {
            return language == .korean ? "릴리스 설정 필요" : "Release setup required"
        }

        return automaticallyChecksForUpdates
            ? (language == .korean ? "새 버전 자동 확인" : "Checks automatically")
            : (language == .korean ? "직접 확인" : "Manual checks")
    }

    func automaticInstallTitle(language: AppLanguage) -> String {
        if !isConfigured {
            return language == .korean ? "릴리스 설정 필요" : "Release setup required"
        }

        if !automaticallyChecksForUpdates {
            return language == .korean ? "자동 확인이 꺼져 있음" : "Auto check is off"
        }

        return automaticallyDownloadsUpdates
            ? (language == .korean ? "가능하면 자동 설치" : "Installs when possible")
            : (language == .korean ? "확인 후 설치" : "Ask before installing")
    }

    func automaticUpdatesTitle(language: AppLanguage) -> String {
        if !isConfigured {
            return language == .korean ? "릴리스 설정 필요" : "Release setup required"
        }

        if !allowsAutomaticUpdates {
            return automaticallyChecksForUpdates
                ? (language == .korean ? "자동 업데이트 켜짐" : "Automatic updates on")
                : (language == .korean ? "자동 업데이트 꺼짐" : "Automatic updates off")
        }

        return automaticUpdatesEnabled
            ? (language == .korean ? "자동 업데이트 켜짐" : "Automatic updates on")
            : (language == .korean ? "자동 업데이트 꺼짐" : "Automatic updates off")
    }

    private func openReleasePage() {
        guard let url = URL(string: "https://github.com/ghkdqhrbals/LidStay/releases/latest") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    #if canImport(Sparkle)
    private func observe(_ updater: SPUUpdater) {
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in
                    self?.sync(from: updater)
                }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in
                    self?.sync(from: updater)
                }
            },
            updater.observe(\.automaticallyDownloadsUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in
                    self?.sync(from: updater)
                }
            },
            updater.observe(\.allowsAutomaticUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in
                    self?.sync(from: updater)
                }
            },
        ]
    }

    private func sync(from updater: SPUUpdater) {
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        allowsAutomaticUpdates = updater.allowsAutomaticUpdates
    }

    private static var hasUsableSparkleConfiguration: Bool {
        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }

        return isUsableSparkleValue(feedURL) && isUsableSparkleValue(publicKey)
    }

    private static func isUsableSparkleValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && !trimmed.contains("$(")
            && !trimmed.localizedCaseInsensitiveContains("REPLACE")
    }
    #endif
}
