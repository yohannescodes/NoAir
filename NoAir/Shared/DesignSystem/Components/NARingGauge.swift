import SwiftUI

/// Animated ring gauge for health metrics. Hero variant shows a big numeral
/// in the center; small variant is a compact metric ring.
struct NARingGauge: View {
    /// Progress from 0 to 1 along the ring.
    let progress: Double
    let gradient: LinearGradient
    var lineWidth: CGFloat = 16
    var size: CGFloat = 190

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    var centerContent: AnyView?

    init(
        progress: Double,
        gradient: LinearGradient,
        lineWidth: CGFloat = 16,
        size: CGFloat = 190,
        @ViewBuilder center: () -> some View
    ) {
        self.progress = progress
        self.gradient = gradient
        self.lineWidth = lineWidth
        self.size = size
        centerContent = AnyView(center())
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceElevated, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(0.001, min(animatedProgress, 1)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let centerContent {
                centerContent
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.1)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                    animatedProgress = newValue
                }
            }
        }
    }
}
