import SwiftUI

struct DisclaimerCardView: View {
    var body: some View {
        CardSurface(title: "Safety", systemImage: "exclamationmark.shield") {
            Text("NoAir is not a medical device, not medical advice, and not for emergency decisions. Follow your clinician’s guidance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
