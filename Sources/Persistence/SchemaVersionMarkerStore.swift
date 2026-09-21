import Foundation

struct SchemaVersionMarkerStore {
    static let key = "persistence.lastSuccessfulSchemaVersion"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Int? {
        guard defaults.object(forKey: Self.key) != nil else { return nil }
        return defaults.integer(forKey: Self.key)
    }

    func save(_ version: Int) {
        defaults.set(version, forKey: Self.key)
    }
}
