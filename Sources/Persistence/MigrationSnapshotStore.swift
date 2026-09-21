import Foundation

/// 保留中のmigration snapshotを識別するためのschema version情報。
struct MigrationSnapshotMetadata: Equatable {
    let sourceVersion: Int?
    let targetVersion: Int
}

protocol MigrationSnapshotStoring {
    func pendingSnapshotMetadata() throws -> MigrationSnapshotMetadata?
    func createPendingSnapshot(storeURL: URL, sourceVersion: Int?, targetVersion: Int) throws
    func restorePendingSnapshot(storeURL: URL) throws
    func deletePendingSnapshot() throws
}

struct MigrationSnapshotStore: MigrationSnapshotStoring {
    struct Manifest: Codable, Equatable {
        let sourceVersion: Int?
        let targetVersion: Int
        let createdAt: Date
        let files: [String]
    }

    enum SnapshotError: Error {
        case pendingSnapshotAlreadyExists
        case missingManifest
        case missingSnapshotFile(String)
    }

    private static let suffixes = ["", "-wal", "-shm", "-journal"]
    private let rootURL: URL
    private let fileManager: FileManager
    private let now: () -> Date

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.now = now
    }

    var pendingURL: URL { rootURL.appendingPathComponent("pending", isDirectory: true) }

    func pendingSnapshotMetadata() throws -> MigrationSnapshotMetadata? {
        guard pendingSnapshotExists else { return nil }
        let manifest = try loadManifest()
        return MigrationSnapshotMetadata(
            sourceVersion: manifest.sourceVersion,
            targetVersion: manifest.targetVersion
        )
    }

    func createPendingSnapshot(
        storeURL: URL,
        sourceVersion: Int?,
        targetVersion: Int
    ) throws {
        guard !pendingSnapshotExists else { throw SnapshotError.pendingSnapshotAlreadyExists }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let temporaryURL = rootURL.appendingPathComponent("temporary-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryURL, withIntermediateDirectories: false)
        var completed = false
        defer {
            if !completed { try? fileManager.removeItem(at: temporaryURL) }
        }

        var files: [String] = []
        for suffix in Self.suffixes {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let name = source.lastPathComponent
            try fileManager.copyItem(at: source, to: temporaryURL.appendingPathComponent(name))
            files.append(name)
        }
        let manifest = Manifest(
            sourceVersion: sourceVersion,
            targetVersion: targetVersion,
            createdAt: now(),
            files: files
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: temporaryURL.appendingPathComponent("manifest.json"), options: .atomic)
        try fileManager.moveItem(at: temporaryURL, to: pendingURL)
        completed = true
    }

    func restorePendingSnapshot(storeURL: URL) throws {
        let manifest = try loadManifest()

        // コピー元がすべて揃っていることを、現行storeへ触れる前に確認する。
        for name in manifest.files
        where !fileManager.fileExists(
            atPath: pendingURL.appendingPathComponent(name).path
        ) {
            throw SnapshotError.missingSnapshotFile(name)
        }
        for suffix in Self.suffixes {
            let destination = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
        for name in manifest.files {
            let suffix = String(name.dropFirst(storeURL.lastPathComponent.count))
            let destination = URL(fileURLWithPath: storeURL.path + suffix)
            try fileManager.copyItem(at: pendingURL.appendingPathComponent(name), to: destination)
        }
    }

    func deletePendingSnapshot() throws {
        guard pendingSnapshotExists else { return }
        try fileManager.removeItem(at: pendingURL)
    }

    private var pendingSnapshotExists: Bool {
        fileManager.fileExists(atPath: pendingURL.path)
    }

    private func loadManifest() throws -> Manifest {
        let manifestURL = pendingURL.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw SnapshotError.missingManifest
        }
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    }
}
