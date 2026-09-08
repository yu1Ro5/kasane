import Foundation

/// ビルド設定からアプリの表示用バージョンを取得する。
enum AppVersion {
    static var current: String {
        shortVersion(from: Bundle.main.infoDictionary)
    }

    static func shortVersion(from infoDictionary: [String: Any]?) -> String {
        guard
            let version = infoDictionary?["CFBundleShortVersionString"] as? String,
            !version.isEmpty
        else {
            return "—"
        }
        return version
    }
}
