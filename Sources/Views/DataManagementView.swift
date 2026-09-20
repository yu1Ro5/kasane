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
    @State private var presentedError: DataManagementError?
    @State private var showsSuccess = false

    var body: some View {
        List {
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
                Text("バックアップ")
            } footer: {
                Text("トレーニング記録をJSONファイルとして保存・復元できます。")
            }
        }
        .navigationTitle("データ管理")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure = result { presentedError = .fileAccess }
            exportDocument = nil
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImportSelection(result)
        }
        .sheet(isPresented: $showsImportPreview) {
            if let pendingBackup {
                ImportPreviewView(backup: pendingBackup) {
                    showsImportPreview = false
                    self.pendingBackup = nil
                } onImport: {
                    importBackup(pendingBackup)
                }
            }
        }
        .alert(item: $presentedError) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .alert("復元しました", isPresented: $showsSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("バックアップのデータで置き換えました。")
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
            presentedError = .export
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
            presentedError = error
        } catch {
            presentedError = .fileAccess
        }
    }

    private func importBackup(_ backup: KASANEBackup) {
        do {
            try KASANEBackupImporter(container: modelContext.container).importBackup(backup)
            showsImportPreview = false
            pendingBackup = nil
            showsSuccess = true
        } catch KASANEBackupImportError.workoutInProgress {
            showsImportPreview = false
            pendingBackup = nil
            presentedError = .workoutInProgress
        } catch {
            showsImportPreview = false
            pendingBackup = nil
            presentedError = .transaction
        }
    }

    private static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "KASANE-backup-\(formatter.string(from: date)).json"
    }
}

private struct ImportPreviewView: View {
    let backup: KASANEBackup
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("バックアップ内容") {
                    LabeledContent("作成日時", value: backup.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("App Version", value: backup.appVersion)
                    LabeledContent("ワークアウト", value: backup.workouts.count.formatted())
                    LabeledContent("種目", value: backup.exercises.count.formatted())
                    LabeledContent("セット", value: setCount.formatted())
                }
                Section {
                    Text("現在のKASANEデータを削除し、選択したバックアップの内容で置き換えます。")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("このバックアップで置き換える", role: .destructive, action: onImport)
                }
            }
            .navigationTitle("復元内容の確認")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
            }
        }
    }

    private var setCount: Int {
        backup.workouts.reduce(0) { total, workout in
            total + workout.exerciseEntries.reduce(0) { $0 + $1.sets.count }
        }
    }
}

private enum DataManagementError: Error, Identifiable {
    case invalidJSON, unsupportedVersion, invalidBackup, workoutInProgress, export, transaction, fileAccess

    var id: Self { self }
    var title: String {
        switch self {
        case .workoutInProgress: "復元できません"
        case .export: "書き出せませんでした"
        default: "バックアップを処理できませんでした"
        }
    }
    var message: String {
        switch self {
        case .invalidJSON: "JSONとして読み込めないファイルです。"
        case .unsupportedVersion: "このバックアップ形式には対応していません。"
        case .invalidBackup: "バックアップの内容が不正です。"
        case .workoutInProgress: "進行中のワークアウトがあります。完了または破棄してからバックアップを復元してください。"
        case .export: "バックアップの作成に失敗しました。"
        case .transaction: "データを変更せずに復元を中止しました。"
        case .fileAccess: "ファイルを読み書きできませんでした。"
        }
    }
}
