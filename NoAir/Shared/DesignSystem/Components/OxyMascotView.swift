import SwiftUI

/// Mascot mood. `calm` is default, `cheer` fires on positive events (quest
/// complete, energy ≥ 7), `watchful` on cautionary ones (energy ≤ 3,
/// environment trigger). Each non-calm mood auto-reverts to calm after its
/// duration.
enum OxyMood: String, CaseIterable, Sendable {
    case calm
    case cheer
    case watchful

    /// How long a triggered mood stays before easing back to calm.
    var duration: TimeInterval {
        switch self {
        case .calm: 0
        case .cheer: 2.0
        case .watchful: 2.4
        }
    }
}

/// Oxy — the calm O₂ bubble. Face is drawn as an exact port of the SVG in
/// the designer's prototype: circle body with stroke arc eyes/mouth per mood.
struct OxyMascotView: View {
    var mood: OxyMood = .calm
    var size: CGFloat = 64
    var showGlow: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var cheerJump = false

    private var animationSpeed: Double {
        mood == .cheer ? 0.8 : 3.2
    }

    var body: some View {
        ZStack {
            if showGlow {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: size * 0.22)
                    .opacity(pulse ? 0.7 : 0.35)
                    .scaleEffect(pulse ? 1.15 : 0.9)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: animationSpeed)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            OxyFace(mood: mood)
                .frame(width: size, height: size)
                .scaleEffect(faceScale)
                .rotationEffect(.degrees(faceRotation))
                .offset(y: faceOffsetY)
                .animation(reduceMotion ? nil : idleAnimation, value: pulse)
                .animation(reduceMotion ? nil : .interpolatingSpring(stiffness: 260, damping: 12), value: cheerJump)
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .onAppear {
            pulse = true
            if mood == .cheer { cheerJump.toggle() }
        }
        .onChange(of: mood) { _, newMood in
            if newMood == .cheer {
                cheerJump.toggle()
            }
        }
    }

    private var idleAnimation: Animation {
        .easeInOut(duration: animationSpeed).repeatForever(autoreverses: true)
    }

    private var faceScale: CGFloat {
        switch mood {
        case .cheer: cheerJump ? 1.22 : 1.05
        case .watchful: pulse ? 1.02 : 1.0
        case .calm: pulse ? 1.045 : 1.0
        }
    }

    private var faceRotation: Double {
        guard mood == .calm else { return 0 }
        return pulse ? 3 : -3
    }

    private var faceOffsetY: CGFloat {
        switch mood {
        case .cheer: cheerJump ? -14 : 2
        case .calm: pulse ? -6 : 0
        case .watchful: 0
        }
    }
}

/// Exact port of the designer's SVG face — canvas viewBox is 124×124.
struct OxyFace: View {
    let mood: OxyMood

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 124.0
            let stroke = 4.0 * scale
            let lineColor = GraphicsContext.Shading.color(Theme.onAccent)
            let bodyColor = GraphicsContext.Shading.color(Theme.accent)

            // Body: <circle cx=62 cy=62 r=48 fill=accent>
            let body = Path(ellipseIn: CGRect(
                x: (62 - 48) * scale, y: (62 - 48) * scale,
                width: 96 * scale, height: 96 * scale
            ))
            context.fill(body, with: bodyColor)

            switch mood {
            case .calm:
                drawCalm(context: &context, scale: scale, stroke: stroke, color: lineColor)
            case .cheer:
                drawCheer(context: &context, scale: scale, stroke: stroke, color: lineColor)
            case .watchful:
                drawWatchful(context: &context, scale: scale, stroke: stroke, color: lineColor)
            }
        }
    }

    // MARK: - Mood paths (points from designer SVG, viewBox 124×124)

    private func drawCalm(context: inout GraphicsContext, scale: Double, stroke: Double, color: GraphicsContext.Shading) {
        // Left eye:  M42 46 q6 4 12 0
        // Right eye: M76 46 q6 4 12 0
        // Mouth:     M56 62 q9 5 18 0
        var eyes = Path()
        eyes.move(to: p(42, 46, scale))
        eyes.addQuadCurve(to: p(54, 46, scale), control: p(48, 50, scale))
        eyes.move(to: p(76, 46, scale))
        eyes.addQuadCurve(to: p(88, 46, scale), control: p(82, 50, scale))

        var mouth = Path()
        mouth.move(to: p(56, 62, scale))
        mouth.addQuadCurve(to: p(74, 62, scale), control: p(65, 67, scale))

        let style = StrokeStyle(lineWidth: stroke, lineCap: .round)
        context.stroke(eyes, with: color, style: style)
        context.stroke(mouth, with: color, style: style)
    }

    private func drawCheer(context: inout GraphicsContext, scale: Double, stroke: Double, color: GraphicsContext.Shading) {
        // Eyes: M41 49 q7 -8 14 0  M75 49 q7 -8 14 0  (arcs opening up = happy squint)
        // Mouth: M52 60 q13 12 26 0 z  (filled semicircle smile)
        var eyes = Path()
        eyes.move(to: p(41, 49, scale))
        eyes.addQuadCurve(to: p(55, 49, scale), control: p(48, 41, scale))
        eyes.move(to: p(75, 49, scale))
        eyes.addQuadCurve(to: p(89, 49, scale), control: p(82, 41, scale))

        var mouth = Path()
        mouth.move(to: p(52, 60, scale))
        mouth.addQuadCurve(to: p(78, 60, scale), control: p(65, 72, scale))
        mouth.closeSubpath()

        let style = StrokeStyle(lineWidth: stroke, lineCap: .round)
        context.stroke(eyes, with: color, style: style)
        context.fill(mouth, with: color)
    }

    private func drawWatchful(context: inout GraphicsContext, scale: Double, stroke: Double, color: GraphicsContext.Shading) {
        // Pupils: <circle cx=48 cy=48 r=5>  <circle cx=82 cy=48 r=5>
        // Brows:  M40 38 l14 -4  M90 38 l-14 -4
        // Mouth:  M57 64 q8 -4 16 0
        let leftEye = Path(ellipseIn: CGRect(
            x: (48 - 5) * scale, y: (48 - 5) * scale,
            width: 10 * scale, height: 10 * scale
        ))
        let rightEye = Path(ellipseIn: CGRect(
            x: (82 - 5) * scale, y: (48 - 5) * scale,
            width: 10 * scale, height: 10 * scale
        ))

        var brows = Path()
        brows.move(to: p(40, 38, scale))
        brows.addLine(to: p(54, 34, scale))
        brows.move(to: p(90, 38, scale))
        brows.addLine(to: p(76, 34, scale))

        var mouth = Path()
        mouth.move(to: p(57, 64, scale))
        mouth.addQuadCurve(to: p(73, 64, scale), control: p(65, 60, scale))

        context.fill(leftEye, with: color)
        context.fill(rightEye, with: color)
        let style = StrokeStyle(lineWidth: stroke, lineCap: .round)
        context.stroke(brows, with: color, style: style)
        context.stroke(mouth, with: color, style: style)
    }

    private func p(_ x: Double, _ y: Double, _ scale: Double) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }
}

/// Confetti burst layered above the mascot for cheer moments.
struct ConfettiBurst: View {
    var count: Int = 14
    var colors: [Color] = [Theme.accent, Theme.streak, Theme.warning]

    @State private var animate = false

    var body: some View {
        Canvas { context, size in
            for i in 0..<count {
                let progress = animate ? 1.0 : 0.0
                let seed = Double(i)
                let angle = seed * 0.7
                let dx = cos(angle) * 60 * progress
                let dy = sin(angle) * 60 * progress + progress * 130
                let x = size.width / 2 + dx
                let y = size.height / 2 + dy
                let rect = CGRect(x: x, y: y, width: 8, height: 8)
                let color = colors[i % colors.count]
                context.opacity = 1.0 - progress
                context.rotate(by: .degrees(seed * 30 * progress))
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: 200, height: 220)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: 1.2)) {
                animate = true
            }
        }
    }
}

#Preview("Oxy moods") {
    HStack(spacing: 20) {
        OxyMascotView(mood: .calm)
        OxyMascotView(mood: .cheer)
        OxyMascotView(mood: .watchful)
    }
    .padding()
    .background(Theme.background)
}
