import Foundation
import SwiftData

/// 組み込み種目を、既存データを変更せずに追加する。
@MainActor
struct ExerciseCatalogService {
    struct BuiltIn: Sendable {
        let id: String
        let name: String
        let bodyPart: BodyPart
    }

    static let builtIns: [BuiltIn] = [
        BuiltIn(id: "00000000-0000-4000-8000-000000000001", name: "ベンチプレス", bodyPart: .chest),
        BuiltIn(id: "00000000-0000-4000-8000-000000000002", name: "チェストプレス", bodyPart: .chest),
        BuiltIn(id: "00000000-0000-4000-8000-000000000003", name: "ペックフライ", bodyPart: .chest),
        BuiltIn(id: "00000000-0000-4000-8000-000000000004", name: "ダンベルプレス", bodyPart: .chest),
        BuiltIn(id: "00000000-0000-4000-8000-000000000005", name: "プッシュアップ", bodyPart: .chest),
        BuiltIn(id: "00000000-0000-4000-8000-000000000006", name: "ラットプルダウン", bodyPart: .back),
        BuiltIn(id: "00000000-0000-4000-8000-000000000007", name: "シーテッドロー", bodyPart: .back),
        BuiltIn(id: "00000000-0000-4000-8000-000000000008", name: "プルアップ", bodyPart: .back),
        BuiltIn(id: "00000000-0000-4000-8000-000000000009", name: "ショルダープレス", bodyPart: .shoulders),
        BuiltIn(id: "00000000-0000-4000-8000-000000000010", name: "サイドレイズ", bodyPart: .shoulders),
        BuiltIn(id: "00000000-0000-4000-8000-000000000011", name: "スクワット", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000012", name: "レッグプレス", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000013", name: "レッグエクステンション", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000014", name: "レッグカール", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000015", name: "ヒップアブダクション", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000016", name: "ヒップアダクション", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000017", name: "カーフレイズ", bodyPart: .legs),
        BuiltIn(id: "00000000-0000-4000-8000-000000000018", name: "ダンベルカール", bodyPart: .arms),
        BuiltIn(id: "00000000-0000-4000-8000-000000000019", name: "トライセプスプレスダウン", bodyPart: .arms),
        BuiltIn(id: "00000000-0000-4000-8000-000000000020", name: "オーバーヘッドトライセプスエクステンション", bodyPart: .arms),
        BuiltIn(id: "00000000-0000-4000-8000-000000000021", name: "アブドミナルクランチ", bodyPart: .core),
        BuiltIn(id: "00000000-0000-4000-8000-000000000022", name: "プランク", bodyPart: .core),
        BuiltIn(id: "00000000-0000-4000-8000-000000000023", name: "デッドリフト", bodyPart: .fullBody),
    ]

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func seed() throws {
        let existingIDs = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.id))
        for item in Self.builtIns {
            guard let id = UUID(uuidString: item.id), !existingIDs.contains(id) else {
                continue
            }
            context.insert(Exercise(id: id, name: item.name, primaryBodyPart: item.bodyPart))
        }
        if context.hasChanges {
            try context.save()
        }
    }
}
