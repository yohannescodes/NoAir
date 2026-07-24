import SwiftData
import SwiftUI

/// Full-screen IMT breathing session (Screens v2 §C9).
///
/// Oxy is the pacer: the mascot scales 1.0 → 1.26 over a 4s inhale, holds,
/// then shrinks back over a 4s exhale. Breath/set counter below tracks
/// progress toward 30 breaths × 3 sets. Writes an `IMTSession` on completion.
///
/// Runs one automatic breath cycle per timer tick; the user can pause at
/// any time. Cancelling before the third set completes does not write a
/// session — partial credit is out of scope for this pass.
struct IMTSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called when the session completes normally (three sets done). The
    /// caller typically dismisses the sheet and flashes a saved bubble.
    let onFinish: () -> Void

    @State private var phase: BreathPhase = .ready
    @State private var breathIndex: Int = 0
    @State private var setIndex: Int = 1
    @State private var isRunning: Bool = false
    @State private var scale: CGFloat = 1.0
    @State private var timer: Timer?

    private let breathsPerSet = 30
    private let setsPerSession = 3
    private let phaseDurationSeconds: TimeInterval = 4

    enum BreathPhase: String {
        case ready = "Ready"
        case inhale = "Breathe in with Oxy"
        case exhale = "Breathe out slowly"
        case rest = "Rest between sets"
        case done = "Nice — session complete"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [Theme.accent.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            ))
                            .frame(width: 260, height: 260)
                            .scaleEffect(scale)
                        OxyPacerFace(inhaling: phase == .inhale)
                            .frame(width: 140, height: 140)
                            .scaleEffect(scale)
                            .animation(.easeInOut(duration: phaseDurationSeconds), value: scale)
                    }

                    VStack(spacing: 4) {
                        Text(phase.rawValue)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.opacity)
                        Text("Oxy grows as you inhale, shrinks as you exhale")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Text("Breath \(breathIndex) of \(breathsPerSet) · Set \(setIndex) of \(setsPerSession)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button(action: toggle) {
                    Text(buttonLabel)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surfaceElevated)
                        )
                }
                .buttonStyle(NAPressableButtonStyle())
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .padding(.top, 52)
        }
        .onDisappear { stop() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("IMT breathing")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
    }

    private var buttonLabel: String {
        switch phase {
        case .ready: "Start breathing"
        case .done: "Done"
        default: isRunning ? "Pause" : "Resume"
        }
    }

    // MARK: - Timer

    private func toggle() {
        switch phase {
        case .done:
            stop()
            dismiss()
        case .ready:
            phase = .inhale
            breathIndex = 1
            setIndex = 1
            isRunning = true
            startTicking()
            withAnimation(.easeInOut(duration: phaseDurationSeconds)) { scale = 1.26 }
        default:
            if isRunning {
                stop()
            } else {
                isRunning = true
                startTicking()
            }
        }
    }

    private func startTicking() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: phaseDurationSeconds, repeats: true) { _ in
            Task { @MainActor in self.tick() }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    @MainActor
    private func tick() {
        switch phase {
        case .inhale:
            phase = .exhale
            withAnimation(.easeInOut(duration: phaseDurationSeconds)) { scale = 1.0 }
        case .exhale:
            if breathIndex >= breathsPerSet {
                // Set complete
                if setIndex >= setsPerSession {
                    complete()
                } else {
                    setIndex += 1
                    breathIndex = 1
                    phase = .rest
                    stop()
                }
            } else {
                breathIndex += 1
                phase = .inhale
                withAnimation(.easeInOut(duration: phaseDurationSeconds)) { scale = 1.26 }
            }
        case .rest, .ready, .done:
            break
        }
    }

    private func complete() {
        stop()
        phase = .done
        let session = IMTSession(
            startedAt: .now,
            setsCompleted: setsPerSession,
            breathsCompleted: setsPerSession * breathsPerSet
        )
        modelContext.insert(session)
        try? modelContext.save()
        onFinish()
    }
}

/// A stripped-down Oxy face that softens on inhale — eyes narrow, mouth
/// rounds to an "o". Reuses the Oxy body colors so it matches everywhere
/// else.
private struct OxyPacerFace: View {
    let inhaling: Bool

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 124.0
            let bodyRect = CGRect(
                x: (62 - 48) * scale,
                y: (62 - 48) * scale,
                width: 96 * scale,
                height: 96 * scale
            )
            context.fill(Path(ellipseIn: bodyRect), with: .color(Theme.accent))

            let ink = GraphicsContext.Shading.color(Theme.onAccent)
            let stroke = 4 * scale

            // Eyes — always a soft closed-arc smile, calm expression.
            var eyes = Path()
            eyes.move(to: CGPoint(x: 42 * scale, y: 46 * scale))
            eyes.addQuadCurve(to: CGPoint(x: 54 * scale, y: 46 * scale), control: CGPoint(x: 48 * scale, y: 50 * scale))
            eyes.move(to: CGPoint(x: 76 * scale, y: 46 * scale))
            eyes.addQuadCurve(to: CGPoint(x: 88 * scale, y: 46 * scale), control: CGPoint(x: 82 * scale, y: 50 * scale))
            context.stroke(eyes, with: ink, style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            if inhaling {
                // Round "o" mouth for inhale.
                let mouthRect = CGRect(
                    x: (62 - 9) * scale,
                    y: (66 - 11) * scale,
                    width: 18 * scale,
                    height: 22 * scale
                )
                context.fill(Path(ellipseIn: mouthRect), with: ink)
            } else {
                // Soft closed smile for exhale/rest.
                var mouth = Path()
                mouth.move(to: CGPoint(x: 56 * scale, y: 62 * scale))
                mouth.addQuadCurve(to: CGPoint(x: 74 * scale, y: 62 * scale), control: CGPoint(x: 65 * scale, y: 67 * scale))
                context.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
    }
}
