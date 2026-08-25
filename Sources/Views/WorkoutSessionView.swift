import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: WorkoutSession

    @State private var isConfirmingDiscard = false
    @State private var errorMessage: String?

    var body: some View {
        ContentUnavailableView {
            Label("種目がありません", systemImage: "dumbbell")
        } description: {
            Text("開始: \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
        } actions: {
            Button("種目を追加") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
        }
        .navigationTitle("ワークアウト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("ワークアウトを破棄", systemImage: "trash", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "このワークアウトを破棄しますか？",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("ワークアウトを破棄", role: .destructive) {
                discardWorkout()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("入力した内容はすべて削除され、元に戻せません。")
        }
        .alert("ワークアウトを破棄できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func discardWorkout() {
        do {
            try WorkoutSessionService(context: modelContext).discard(session)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
