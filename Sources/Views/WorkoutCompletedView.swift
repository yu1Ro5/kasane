import SwiftUI

/// 保存済みワークアウトの集計結果とホームへ戻る導線を表示する完了画面。
struct WorkoutCompletedView: View {
    /// 保存に成功したワークアウトの集計結果。
    let summary: WorkoutCompletionSummary
    /// 「完了」を選択したときに実行する処理。
    let onReturnHome: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("ワークアウトを記録しました")
                .font(.title2.bold())

            Grid(horizontalSpacing: 28, verticalSpacing: 12) {
                summaryRow("トレーニング時間", value: durationText)
                summaryRow("種目数", value: "\(summary.exerciseCount)")
                summaryRow("セット数", value: "\(summary.setCount)")
            }

            Button("完了", action: onReturnHome)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden()
    }

    private var durationText: String {
        let totalMinutes = Int(summary.duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).bold()
        }
    }
}
