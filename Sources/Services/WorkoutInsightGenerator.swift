import Foundation
import FoundationModels

@MainActor
protocol WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight
}

enum WorkoutInsightGenerationError: Error, Equatable {
    case unavailable
}

struct AppleIntelligenceWorkoutInsightGenerator: WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(.current) else {
            throw WorkoutInsightGenerationError.unavailable
        }

        let session = LanguageModelSession {
            """
            あなたは筋力トレーニング記録の短い振り返り文を作る編集者です。
            入力として渡された事実だけを使用してください。
            入力に存在しない数値、種目、自己ベスト、比較結果を追加・推測しないでください。
            「前回より増えた」「自己ベストを更新した」などの表現は、入力でその事実が明示されている場合だけ使用してください。
            特に注目すべき事実を最大2つ選び、Workout完了画面に収まる短く自然な日本語で表現してください。
            同じ事実を見出しと本文で不自然に重複させないでください。
            ユーザーの努力量を評価しないでください。「もっと頑張りましょう」「不足しています」などの表現を使わないでください。
            健康状態・怪我・疲労・医療的な評価やフォーム評価をしないでください。
            次回の重量、回数、セット数、Workout内容を提案しないでください。
            """
        }
        let response = try await session.respond(
            to: Self.prompt(from: facts),
            generating: GeneratedWorkoutInsight.self
        )
        return response.content
    }

    static func prompt(from facts: WorkoutInsightFacts) -> String {
        var lines = [
            "Workoutの事実:",
            "トレーニング時間: \(Int(facts.duration) / 60)分",
            "種目数: \(facts.exerciseCount)",
            "セット数: \(facts.setCount)",
            "総Volume: \(number(facts.totalVolume))kg",
        ]
        if !facts.personalRecords.isEmpty {
            lines.append("自己ベスト:")
            for record in facts.personalRecords {
                lines.append(contentsOf: [
                    "- \(record.exerciseName)",
                    "  previous: \(number(record.previousBest))kg",
                    "  new: \(number(record.newBest))kg",
                    "  improvement: \(signedNumber(record.improvement))kg",
                ])
            }
        }
        if !facts.exerciseComparisons.isEmpty {
            lines.append("前回との比較:")
            for comparison in facts.exerciseComparisons {
                lines.append(contentsOf: [
                    "- \(comparison.exerciseName)",
                    "  最大重量: \(number(comparison.previousMaxWeight))kg → \(number(comparison.currentMaxWeight))kg",
                    "  最大重量差分: \(signedNumber(comparison.maxWeightDifference))kg",
                    "  Volume: \(number(comparison.previousVolume))kg → \(number(comparison.currentVolume))kg",
                    "  Volume差分: \(signedNumber(comparison.volumeDifference))kg",
                ])
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)))
    }

    private static func signedNumber(_ value: Double) -> String {
        (value > 0 ? "+" : "") + number(value)
    }
}

struct FixtureWorkoutInsightGenerator: WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        GeneratedWorkoutInsight(
            headline: "記録を更新",
            message: "自己ベストを更新しました。前回よりボリュームも増えています。"
        )
    }
}

struct UnavailableFixtureWorkoutInsightGenerator: WorkoutInsightGenerating {
    func generate(from facts: WorkoutInsightFacts) async throws -> GeneratedWorkoutInsight {
        throw WorkoutInsightGenerationError.unavailable
    }
}
