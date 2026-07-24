import SwiftUI

/// Cold-launch splash animation per `design_handoff_launch_screen/README.md`.
///
/// Sequence (user-directed 7s total, extended from the handoff's 2.6s):
///  - 0.0-1.4s  · **Roll in** — Oxy enters from off-screen left,
///                rotates ~410° while translating to center, spring
///                overshoot/settle at the end. Simultaneous vertical
///                bounce peaking around 30% of the roll to sell weight.
///  - 1.4-2.1s  · **Catch breath** — 0.7s of stillness before the
///                first breath. Sells "just landed, needs a beat" the
///                way an unoperated-CHD patient does after mild
///                exertion.
///  - 2.1-4.6s  · **Labored first breath** — one big slow cycle
///                (~2.5s, scale to 1.20). Reads as post-exertion, not
///                calm. Ground shadow + wordmark fade in during the
///                exhale.
///  - 4.6-6.6s  · **Settle** — two calmer cycles (~1.0s each, scale
///                to 1.08), rhythm returning to baseline.
///  - 6.6-7.0s  · **Dismiss** — 400ms opacity fade out; onDone() fires
///                so the caller can route to Onboarding or Home.
///
/// The breathing sequence is deliberate: for the audience (adults with
/// unoperated cyanotic CHD), a stock "calm loop" would ring hollow. A
/// mascot that visibly catches its breath after a small effort maps
/// exactly to their daily experience — and telegraphs "this app gets
/// it" before any copy loads.
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

    // Breathe state — a driven scale (0.94 exhale, 1.20 labored inhale,
    // 1.08 calm inhale) rather than a repeatForever loop, so we can pace
    // the labored → settling arc explicitly.
    @State private var breathScale: CGFloat = 1.0

    // Reveal state
    @State private var showsShadow = false
    @State private var showsWordmark = false
    @State private var dismissed = false

    private let rollDuration: Double = 1.4
    private let catchBreathPause: Double = 0.7
    private let laboredInhaleDuration: Double = 1.4
    private let laboredExhaleDuration: Double = 1.1
    private let calmCycleDuration: Double = 1.0
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
                    .scaleEffect(breathScale)
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
        // Reduce-motion: skip the roll and the breathe. Snap into a static
        // Oxy with the wordmark; dismiss on the same 7s budget so the
        // caller's downstream routing timing is consistent.
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

        // Post-roll: catch-breath pause, then breathe sequence.
        // Timeline (seconds from launch):
        //   1.4  → shadow + wordmark start fading in
        //   2.1  → labored inhale begins
        //   3.5  → labored exhale begins
        //   4.6  → first calm cycle begins
        //   5.6  → second calm cycle begins
        //   6.6  → dismiss fade starts
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration) {
            withAnimation(.easeIn(duration: 0.5)) {
                showsShadow = true
                showsWordmark = true
            }
        }

        let breatheStart = rollDuration + catchBreathPause
        DispatchQueue.main.asyncAfter(deadline: .now() + breatheStart) {
            performBreatheSequence()
        }

        // Dismiss at 7s total, with a 400ms fade at the tail.
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration - dismissDuration) {
            dismiss()
        }
    }

    /// One deep labored breath, then two calmer cycles as the rhythm
    /// settles. Each phase is a separate driven animation so the arc
    /// (labored → settling) is visible, not a homogeneous loop.
    private func performBreatheSequence() {
        // Labored inhale — big, slow scale up.
        withAnimation(.easeInOut(duration: laboredInhaleDuration)) {
            breathScale = 1.20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + laboredInhaleDuration) {
            // Labored exhale — return to slight under-rest.
            withAnimation(.easeInOut(duration: laboredExhaleDuration)) {
                breathScale = 0.96
            }
        }

        // Two calmer settling cycles.
        let firstCalmStart = laboredInhaleDuration + laboredExhaleDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + firstCalmStart) {
            withAnimation(.easeInOut(duration: calmCycleDuration / 2)) {
                breathScale = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + calmCycleDuration / 2) {
                withAnimation(.easeInOut(duration: calmCycleDuration / 2)) {
                    breathScale = 1.0
                }
            }
        }
        let secondCalmStart = firstCalmStart + calmCycleDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + secondCalmStart) {
            withAnimation(.easeInOut(duration: calmCycleDuration / 2)) {
                breathScale = 1.06
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + calmCycleDuration / 2) {
                withAnimation(.easeInOut(duration: calmCycleDuration / 2)) {
                    breathScale = 1.0
                }
            }
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
