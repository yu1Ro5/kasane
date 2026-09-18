import Foundation
import FoundationModels

@MainActor
protocol MonthlyInsightGenerating {
    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight
}

enum MonthlyInsightGenerationError: Error {
    case unavailable
}

struct AppleIntelligenceMonthlyInsightGenerator: MonthlyInsightGenerating {
    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(.current) else {
            throw MonthlyInsightGenerationError.unavailable
        }

        let session = LanguageModelSession {
            """
            あなたは筋力トレーニング履歴の月間サマリーを短く編集する役割です。
            入力として渡された事実だけを使用してください。
            入力にない数値、種目、自己ベスト、比較結果を追加・推測しないでください。
            その月を特徴づける事実を最大2つ選び、1〜2文の簡潔な日本語で表現してください。
            良い月・悪い月という総合評価はしないでください。
            努力不足、休みすぎ等の否定的評価をしないでください。
            健康状態やフォームの評価をしないでください。
            次回の重量、回数、セット数、Workout内容を提案しないでください。
            """
        }
        let response = try await session.respond(
            to: Self.prompt(from: facts),
            generating: GeneratedMonthlyInsight.self
        )
        return response.content
    }

    static func prompt(from facts: MonthlyInsightFacts) -> String {
        var lines = [
            "月間トレーニングの事実:",
            "対象月: \(facts.month.formatted(.dateTime.year().month()))",
            "Workout回数: \(facts.workoutCount)回",
            "合計時間: \(max(0, Int(facts.totalDuration)) / 60)分",
            "総Volume: \(number(facts.totalVolume))kg",
            "実施日数: \(facts.activeDays)日",
            "連続実施週: \(facts.streakWeeks)週",
        ]
        if let record = facts.personalRecord {
            lines.append(
                "自己ベスト: \(record.exerciseName), \(number(record.weight))kg, 更新幅 +\(number(record.improvement))kg"
            )
        }
        if let improvement = facts.improvement {
            lines.append(
                "前回からの更新: \(improvement.exerciseName), \(number(improvement.weight))kg, 差 +\(number(improvement.improvement))kg"
            )
        }
        if let exercise = facts.mostFrequentExercise {
            lines.append("最も多く含まれた種目: \(exercise.exerciseName), \(exercise.workoutCount)Workout")
        }
        return lines.joined(separator: "\n")
    }

    private static func number(_ value: Double) -> String {
        value.formatted(
            .number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2))
        )
    }
}

struct FixtureMonthlyInsightGenerator: MonthlyInsightGenerating {
    func generate(from facts: MonthlyInsightFacts) async throws -> GeneratedMonthlyInsight {
        GeneratedMonthlyInsight(
            message: "今月は8回トレーニング。特にレッグプレスの記録が着実に伸びています。"
        )
    }
}
