import Foundation

struct KASANEBackup: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let exportedAt: Date
    let appVersion: String
    let exercises: [ExerciseBackup]
    let workouts: [WorkoutBackup]
}

struct ExerciseBackup: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let primaryBodyPart: String
    let isArchived: Bool
}

struct WorkoutBackup: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let note: String?
    let exerciseEntries: [ExerciseEntryBackup]
}

struct ExerciseEntryBackup: Codable, Equatable, Sendable {
    let id: UUID
    let exerciseID: UUID?
    let exerciseNameSnapshot: String
    let primaryBodyPartSnapshot: String
    let order: Int
    let sets: [SetEntryBackup]
}

struct SetEntryBackup: Codable, Equatable, Sendable {
    let id: UUID
    let order: Int
    let weightKg: Double
    let reps: Int
    let isWarmup: Bool
}
