import SwiftUI

struct WorkoutSetColumnHeader: View {
    var body: some View {
        WorkoutSetColumns {
            Text("セット")
        } weight: {
            Text("重量")
        } reps: {
            Text("回数")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct WorkoutSetColumns<SetColumn: View, WeightColumn: View, RepsColumn: View>: View {
    @ViewBuilder let set: SetColumn
    @ViewBuilder let weight: WeightColumn
    @ViewBuilder let reps: RepsColumn

    var body: some View {
        HStack(spacing: 12) {
            set
                .frame(maxWidth: .infinity, alignment: .leading)
            weight
                .frame(maxWidth: .infinity, alignment: .trailing)
            reps
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct WorkoutWeightText: View {
    let weightKg: Double

    private var parts: WorkoutSetDisplayFormatter.WeightParts {
        WorkoutSetDisplayFormatter.weightParts(weightKg)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(parts.integer)
                .frame(minWidth: 0, alignment: .trailing)
            ZStack(alignment: .leading) {
                Text(".00")
                    .hidden()
                if let fraction = parts.fraction {
                    Text(".\(fraction)")
                }
            }
            Text(" kg")
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WorkoutSetDisplayFormatter.weight(weightKg))
    }
}
