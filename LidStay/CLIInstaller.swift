import Foundation
import Darwin

enum CLIInstaller {
    private static let installURL = URL(fileURLWithPath: "/usr/local/bin/lidstay")
    private static let knownCLIURLs = [
        URL(fileURLWithPath: "/usr/local/bin/lidstay"),
        URL(fileURLWithPath: "/opt/homebrew/bin/lidstay"),
    ]

    static func installBundledCLIIfNeeded() {
        guard let bundledURL = Bundle.main.url(forResource: "lidstay", withExtension: nil),
              FileManager.default.fileExists(atPath: bundledURL.path),
              !anyInstalledCLIMatches(bundledURL: bundledURL) else {
            return
        }

        if installDirectly(from: bundledURL) {
            return
        }
    }

    private static func anyInstalledCLIMatches(bundledURL: URL) -> Bool {
        guard let bundledData = try? Data(contentsOf: bundledURL) else {
            return false
        }

        return knownCLIURLs.contains { url in
            guard let installedData = try? Data(contentsOf: url) else {
                return false
            }

            return bundledData == installedData
        }
    }

    private static func installDirectly(from bundledURL: URL) -> Bool {
        do {
            let binURL = installURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: installURL.path) {
                try FileManager.default.removeItem(at: installURL)
            }

            try FileManager.default.copyItem(at: bundledURL, to: installURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installURL.path)
            removeQuarantineAttribute(at: installURL)
            return true
        } catch {
            return false
        }
    }

    private static func removeQuarantineAttribute(at url: URL) {
        _ = url.path.withCString { path in
            removexattr(path, "com.apple.quarantine", 0)
        }
    }
}
