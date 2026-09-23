import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportDocument: KASANEBackupDocument?
    @State private var exportFilename = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showsImportPreview = false
    @State private var pendingBackup: KASANEBackup?
    @State private var pendingCloudRestore: KASANEPreparedICloudRestore?
    @State private var latestBackupState: LatestBackupState = .checking
    @State private var cloudOperation: CloudOperation?
    @State private var presentedNotice: DataManagementNotice?

    var body: some View {
        List {
            Section {
                LabeledContent("最終バックアップ") {
                    latestBackupValue
                }
                Button {
                    Task { await backupToICloud() }
                } label: {
                    operationLabel(
                        title: "今すぐバックアップ",
                        systemImage: "icloud.and.arrow.up",
                        operation: .backingUp
                    )
                }
                .disabled(cloudOperation != nil || latestBackupState.isChecking)
                .accessibilityIdentifier("icloud-backup")

                Button {
                    Task { await loadICloudRestore() }
                } label: {
                    operationLabel(
                        title: "iCloudから復元",
                        systemImage: "icloud.and.arrow.down",
                        operation: .loadingRestore
                    )
                }
                .disabled(cloudOperation != nil || latestBackupState.isChecking)
                .accessibilityIdentifier("icloud-restore")
            } header: {
                Text("iCloudバックアップ")
                    .accessibilityIdentifier("icloud-backup-section")
            } footer: {
                Text("iCloud Driveにトレーニング記録の完全バックアップを保存します。")
            }

            Section {
                Button(action: prepareExport) {
                    Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("backup-export")

                Button {
                    isImporting = true
                } label: {
                    Label("バックアップから復元", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("backup-import")
            } header: {
                Text("ファイルバックアップ")
            } footer: {
                Text("トレーニング記録をJSONファイルとして保存・復元できます。")
            }
        }
        .navigationTitle("データ管理")
        .task { await refreshLatestBackup() }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure = result { presentedNotice = .error(.fileAccess) }
            exportDocument = nil
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImportSelection(result)
        }
        .sheet(isPresented: $showsImportPreview) {
            if let pendingBackup {
                BackupPreviewView(
                    title: "復元内容の確認",
                    backup: pendingBackup,
                    warning: "現在のKASANEデータを削除し、選択したバックアップの内容で置き換えます。",
                    isWorking: false
                ) {
                    showsImportPreview = false
                    self.pendingBackup = nil
                } onImport: {
                    importFileBackup(pendingBackup)
                }
            }
        }
        .sheet(item: $pendingCloudRestore) { prepared in
            BackupPreviewView(
                title: "iCloudバックアップから復元",
                backup: prepared.backup,
                warning: "現在のKASANEデータを削除し、iCloudバックアップの内容で置き換えます。",
                isWorking: cloudOperation == .restoring
            ) {
                pendingCloudRestore = nil
            } onImport: {
                Task { await restoreFromICloud(prepared) }
            }
            .interactiveDismissDisabled(cloudOperation == .restoring)
        }
        .alert(item: $presentedNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var latestBackupValue: some View {
        switch latestBackupState {
        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                Text("確認中…")
            }
            .accessibilityElement(children: .combine)
        case .none:
            Text("なし")
                .foregroundStyle(.secondary)
        case .available(let date):
            Text(date.formatted(date: .numeric, time: .shortened))
        case .unavailable:
            Text("iCloudを利用できません")
                .foregroundStyle(.secondary)
        case .failed:
            Text("確認できませんでした")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func operationLabel(
        title: String,
        systemImage: String,
        operation: CloudOperation
    ) -> some View {
        if cloudOperation == operation {
            HStack {
                ProgressView()
                Text(operation.progressTitle)
            }
            .accessibilityElement(children: .combine)
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    private var cloudService: KASANEICloudBackupService {
        KASANEICloudBackupService(
            container: modelContext.container,
            cloudStore: KASANEICloudBackupStore(),
            safetyStore: KASANEPreRestoreBackupStore()
        )
    }

    private func refreshLatestBackup() async {
        latestBackupState = .checking
        do {
            if let summary = try await cloudService.latestBackupSummary() {
                latestBackupState = .available(summary.exportedAt)
            } else {
                latestBackupState = .none
            }
        } catch let error as KASANEICloudBackupServiceError {
            latestBackupState = error.isICloudUnavailable ? .unavailable : .failed
        } catch {
            latestBackupState = .failed
        }
    }

    private func backupToICloud() async {
        guard cloudOperation == nil else { return }
        cloudOperation = .backingUp
        defer { cloudOperation = nil }
        do {
            let summary = try await cloudService.backupNow()
            latestBackupState = .available(summary.exportedAt)
            presentedNotice = .iCloudBackupSucceeded
        } catch let error as KASANEICloudBackupServiceError {
            presentedNotice = .error(.iCloud(error))
            if error.isICloudUnavailable { latestBackupState = .unavailable }
        } catch {
            presentedNotice = .error(.iCloud(.writeFailed))
        }
    }

    private func loadICloudRestore() async {
        guard cloudOperation == nil else { return }
        cloudOperation = .loadingRestore
        defer { cloudOperation = nil }
        do {
            pendingCloudRestore = try await cloudService.prepareRestore()
        } catch let error as KASANEICloudBackupServiceError {
            presentedNotice = .error(.iCloud(error))
        } catch {
            presentedNotice = .error(.iCloud(.readFailed))
        }
    }

    private func restoreFromICloud(_ prepared: KASANEPreparedICloudRestore) async {
        guard cloudOperation == nil else { return }
        cloudOperation = .restoring
        do {
            try await cloudService.restore(prepared)
            cloudOperation = nil
            pendingCloudRestore = nil
            presentedNotice = .iCloudRestoreSucceeded
        } catch let error as KASANEICloudBackupServiceError {
            cloudOperation = nil
            pendingCloudRestore = nil
            presentedNotice = .error(.iCloud(error))
        } catch {
            cloudOperation = nil
            pendingCloudRestore = nil
            presentedNotice = .error(.iCloud(.importFailed))
        }
    }

    private func prepareExport() {
        do {
            let now = Date()
            let data = try KASANEBackupExporter(container: modelContext.container).makeJSONData(now: now)
            exportDocument = KASANEBackupDocument(data: data)
            exportFilename = Self.filename(for: now)
            isExporting = true
        } catch {
            presentedNotice = .error(.export)
        }
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let backup: KASANEBackup
            do {
                backup = try KASANEBackupCoding.decode(data)
            } catch {
                throw DataManagementError.invalidJSON
            }
            do {
                try KASANEBackupValidator.validate(backup)
            } catch let error as KASANEBackupValidationError {
                if case .unsupportedFormatVersion = error {
                    throw DataManagementError.unsupportedVersion
                }
                throw DataManagementError.invalidBackup
            }
            pendingBackup = backup
            showsImportPreview = true
        } catch let error as DataManagementError {
            presentedNotice = .error(error)
        } catch {
            presentedNotice = .error(.fileAccess)
        }
    }

    private func importFileBackup(_ backup: KASANEBackup) {
        do {
            try KASANEBackupImporter(container: modelContext.container).importBackup(backup)
            showsImportPreview = false
            pendingBackup = nil
            presentedNotice = .fileRestoreSucceeded
        } catch KASANEBackupImportError.workoutInProgress {
            showsImportPreview = false
            pendingBackup = nil
            presentedNotice = .error(.workoutInProgress)
        } catch {
            showsImportPreview = false
            pendingBackup = nil
            presentedNotice = .error(.transaction)
        }
    }

    private static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "KASANE-backup-\(formatter.string(from: date)).json"
    }
}

private struct BackupPreviewView: View {
    let title: String
    let backup: KASANEBackup
    let warning: String
    let isWorking: Bool
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("バックアップ内容") {
                    LabeledContent(
                        "バックアップ日時",
                        value: backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent("App Version", value: backup.appVersion)
                    LabeledContent("ワークアウト", value: summary.workoutCount.formatted())
                    LabeledContent("種目", value: summary.exerciseCount.formatted())
                    LabeledContent("セット", value: summary.setCount.formatted())
                }
                Section {
                    Text(warning)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("このバックアップで置き換える", role: .destructive, action: onImport)
                        .disabled(isWorking)
                        .accessibilityHint("現在のデータを削除してバックアップの内容で置き換えます")
                    if isWorking {
                        HStack {
                            ProgressView()
                            Text("復元中…")
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                        .disabled(isWorking)
                }
            }
        }
    }

    private var summary: KASANEBackupSummary { KASANEBackupSummary(backup: backup) }
}

private enum LatestBackupState {
    case checking
    case none
    case available(Date)
    case unavailable
    case failed

    var isChecking: Bool {
        if case .checking = self { true } else { false }
    }
}

private enum CloudOperation: Equatable {
    case backingUp
    case loadingRestore
    case restoring

    var progressTitle: String {
        switch self {
        case .backingUp: "バックアップ中…"
        case .loadingRestore: "バックアップを読み込み中…"
        case .restoring: "復元中…"
        }
    }
}

private enum DataManagementNotice: Identifiable {
    case error(DataManagementError)
    case iCloudBackupSucceeded
    case iCloudRestoreSucceeded
    case fileRestoreSucceeded

    var id: String { "\(self)" }
    var title: String {
        switch self {
        case .error(let error): error.title
        case .iCloudBackupSucceeded: "iCloud Driveに保存しました"
        case .iCloudRestoreSucceeded, .fileRestoreSucceeded: "復元しました"
        }
    }
    var message: String {
        switch self {
        case .error(let error): error.message
        case .iCloudBackupSucceeded: "最新のトレーニング記録をiCloud Driveに保存しました。ほかの端末に反映されるまで時間がかかる場合があります。"
        case .iCloudRestoreSucceeded: "iCloudバックアップのデータで置き換えました。"
        case .fileRestoreSucceeded: "バックアップのデータで置き換えました。"
        }
    }
}

private enum DataManagementError: Error {
    case invalidJSON
    case unsupportedVersion
    case invalidBackup
    case workoutInProgress
    case export
    case transaction
    case fileAccess
    case iCloud(KASANEICloudBackupServiceError)

    var title: String {
        switch self {
        case .workoutInProgress, .iCloud(.workoutInProgress): "復元できません"
        case .export: "書き出せませんでした"
        case .iCloud(.iCloudUnavailable), .iCloud(.containerUnavailable): "iCloudを利用できません"
        case .iCloud(.safetyBackupFailed): "復元前のバックアップに失敗しました"
        case .iCloud(.writeFailed): "iCloudに保存できませんでした"
        case .iCloud(.backupNotFound): "バックアップがありません"
        default: "バックアップを処理できませんでした"
        }
    }

    var message: String {
        switch self {
        case .invalidJSON, .iCloud(.invalidJSON): "JSONとして読み込めないバックアップです。"
        case .unsupportedVersion, .iCloud(.unsupportedFormatVersion):
            "このバックアップ形式には対応していません。"
        case .invalidBackup, .iCloud(.invalidBackup): "バックアップの内容が不正です。"
        case .workoutInProgress, .iCloud(.workoutInProgress):
            "進行中のワークアウトがあります。完了または破棄してからバックアップを復元してください。"
        case .export, .iCloud(.exportFailed): "バックアップの作成に失敗しました。"
        case .transaction, .iCloud(.importFailed): "データを変更せずに復元を中止しました。"
        case .fileAccess: "ファイルを読み書きできませんでした。"
        case .iCloud(.iCloudUnavailable): "Apple IDとiCloud Driveの設定を確認してください。"
        case .iCloud(.containerUnavailable): "iCloudのバックアップ領域を取得できませんでした。"
        case .iCloud(.backupNotFound): "復元できるiCloudバックアップがありません。"
        case .iCloud(.downloadFailed): "iCloudからバックアップをダウンロードできませんでした。"
        case .iCloud(.downloadTimedOut): "iCloudからのダウンロードが時間内に完了しませんでした。"
        case .iCloud(.readFailed): "iCloudのバックアップを読み込めませんでした。"
        case .iCloud(.writeFailed): "iCloudへの書き込みに失敗しました。"
        case .iCloud(.safetyBackupFailed):
            "現在のデータを安全に退避できなかったため、復元を開始しませんでした。"
        }
    }
}

extension KASANEICloudBackupServiceError {
    fileprivate var isICloudUnavailable: Bool {
        self == .iCloudUnavailable || self == .containerUnavailable
    }
}
