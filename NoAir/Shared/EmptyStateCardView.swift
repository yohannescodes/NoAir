import SwiftUI

struct EmptyStateCardView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        CardSurface(title: title, systemImage: systemImage) {
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}
