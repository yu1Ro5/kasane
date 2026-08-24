import SwiftUI

struct ContentView: View {
    static let title = "KASANE"
    static let subtitle = "Training, accumulated."

    var body: some View {
        VStack(spacing: 12) {
            Text(Self.title)
                .font(.largeTitle.bold())
            Text(Self.subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
