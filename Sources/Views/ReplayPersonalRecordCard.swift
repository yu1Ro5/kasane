import SwiftUI

struct ReplayPersonalRecordCard: View {
    let year: Int
    let countText: String

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: "trophy.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text("\(year)年の自己ベスト更新")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(countText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()

                Text("最大使用重量の自己ベスト")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(year)年の自己ベスト更新")
        .accessibilityValue("最大使用重量の自己ベスト、\(countText)")
    }
}
