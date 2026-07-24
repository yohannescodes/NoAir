import SwiftUI

/// Cold-launch splash animation per `design_handoff_launch_screen/README.md`.
///
/// Sequence (user-directed 7s total, extended from the handoff's 2.6s):
///  - 0.0-1.4s  · **Roll in** — Oxy enters from off-screen left,
///                rotates ~410° while translating to center, spring
///                overshoot/settle at the end. Simultaneous vertical
///                bounce peaking around 30% of the roll to sell weight.
///  - 1.4-1.9s  · **Ground shadow** fades in under the mascot (sells
///                "resting on a surface").
///  - 1.9-6.6s  · **Breathe** — gentle scale loop (1 → 1.16 → 1) on a
///                1.6s cycle, "Oxylittle" wordmark fades in below.
///  - 6.6-7.0s  · **Dismiss** — 400ms opacity fade out; onDone() fires
///                so the caller can route to Onboarding or Home.
///
/// Cold-launch only — the caller in ContentView gates on a `showsLaunch`
/// state that starts true, so scene reactivations from background don't
/// re-fire the animation.
struct LaunchAnimationView: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Roll state (0-1.4s)
    @State private var rolled = false
    @State private var bounced = false

    // Breathe state (post-settle loop)
    @State private var breathing = false

    // Reveal state
    @State private var showsShadow = false
    @State private var showsWordmark = false
    @State private var dismissed = false

    private let rollDuration: Double = 1.4
    private let breatheCycle: Double = 1.6
    private let totalDuration: Double = 7.0
    private let dismissDuration: Double = 0.4

    var body: some View {
        GeometryReader { proxy in
            let center = CGSize(width: proxy.size.width / 2, height: proxy.size.height / 2)
            ZStack {
                Theme.background.ignoresSafeArea()

                // Ground shadow that fades in after the roll settles.
                Ellipse()
                    .fill(Theme.accent)
                    .frame(width: 130, height: 22)
                    .blur(radius: 12)
                    .opacity(showsShadow ? 0.18 : 0)
                    .offset(y: 66)
                    .position(x: center.width, y: center.height)

                // The mascot — rolls in, then breathes.
                OxyFace(mood: .calm)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rolled ? 0 : -410))
                    .offset(
                        x: rolled ? 0 : -(proxy.size.width / 2 + 140),
                        y: bounced ? 0 : -22
                    )
                    .scaleEffect(breathing ? 1.16 : 1.0)
                    .position(x: center.width, y: center.height)

                // Wordmark below the mascot.
                Text("Oxylittle")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.6)
                    .opacity(showsWordmark ? 1 : 0)
                    .position(x: center.width, y: center.height + 106)
            }
            .opacity(dismissed ? 0 : 1)
            .onAppear { runSequence() }
        }
    }

    private func runSequence() {
        // Reduce-motion: skip the roll, snap into a static Oxy with the
        // wordmark, dismiss on the same 7s budget so the caller's
        // downstream routing timing is consistent.
        if reduceMotion {
            rolled = true
            bounced = true
            showsShadow = true
            showsWordmark = true
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration - dismissDuration) {
                dismiss()
            }
            return
        }

        // Roll in + bounce (0-1.4s). The two animations share the same
        // duration but different curves so the bounce peaks mid-roll.
        withAnimation(.timingCurve(0.3, 0.7, 0.4, 1.0, duration: rollDuration)) {
            rolled = true
        }
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 8).delay(0.05)) {
            bounced = true
        }

        // Ground shadow (1.4-1.9s).
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration) {
            withAnimation(.easeIn(duration: 0.5)) {
                showsShadow = true
                showsWordmark = true
            }
            startBreathing()
        }

        // Dismiss at 7s total, with a 400ms fade at the tail.
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration - dismissDuration) {
            dismiss()
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: breatheCycle).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: dismissDuration)) {
            dismissed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) {
            onDone()
        }
    }
}

#Preview {
    LaunchAnimationView(onDone: {})
        .preferredColorScheme(.dark)
}
