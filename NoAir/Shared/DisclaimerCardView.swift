import SwiftUI

struct DisclaimerCardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.mint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Safety")
                    .font(.subheadline.weight(.semibold))

                Text("NoAir is not a medical device or medical advice. Do not use it for emergency decisions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
