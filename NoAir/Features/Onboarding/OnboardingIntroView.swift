import SwiftUI

/// Pre-setup onboarding intro (Spec v2 §21, Screens v2 §K1-§K3).
///
/// Runs *before* the conversational setup so first launch isn't a cold
/// drop into forms. Three screens: Welcome, Meet Oxy, From the developer.
/// Skip (top-right) or "Let's set up" on K3 both call `onFinish()` — the
/// container then routes into the existing `OnboardingView`.
///
/// Gated by the same `UserPreferences.onboardingComplete` flag as the
/// setup flow: Settings → Reset onboarding replays from K1.
///
/// Developer note is static config (not localized, not user-editable at
/// runtime) — the "editable without a rebuild" requirement in the spec
/// is satisfied by keeping the copy in a single constant here rather
/// than scattering it in the view body.
struct OnboardingIntroView: View {
    /// Called when the user taps Skip or finishes K3.
    let onFinish: () -> Void

    @State private var index: Int = 0

    // Static developer config — one place to edit copy.
    private let developerName = "Yohannes"
    private let developerRole = "Indie developer · living with a cardiac condition"
    private let developerNote = "\"I built Oxylittle because tracking my own oxygen felt clinical and lonely. I wanted something that felt like a friend checking in - gentle, honest, and mine. I hope it helps you the way it helps me.\""
    private let developerInitial = "Y"

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack {
                topBar

                ZStack {
                    switch index {
                    case 0: welcome
                    case 1: meetOxy
                    default: developerNoteScreen
                    }
                }
                .frame(maxHeight: .infinity)

                pageDots
                    .padding(.bottom, 12)

                Button(action: advance) {
                    Text(index == 2 ? "Let's set up" : "Next")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent)
                        )
                        .shadow(color: Theme.accentEdge, radius: 0, x: 0, y: 4)
                }
                .buttonStyle(NAPressableButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: index)
    }

    // MARK: - Layout pieces

    /// K1 uses a mint→bg gradient per the frame; K2 and K3 sit on the
    /// standard dark background.
    @ViewBuilder
    private var background: some View {
        if index == 0 {
            LinearGradient(
                colors: [Color(uiColor: .init(red: 0.047, green: 0.227, blue: 0.204, alpha: 1)), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Theme.background
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                onFinish()
            } label: {
                Text("Skip")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
        .padding(.horizontal, 12)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(i == index ? Theme.accent : Color(uiColor: .init(red: 0.227, green: 0.275, blue: 0.325, alpha: 1)))
                    .frame(width: i == index ? 22 : 6, height: 6)
            }
        }
    }

    // MARK: - Screens

    private var welcome: some View {
        VStack(spacing: 20) {
            OxyMascotView(mood: .calm, size: 96)
                .padding(.top, 20)
            Text("WELCOME TO")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
                .tracking(1.2)
            Text("Oxylittle")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("A calmer way to keep an eye on your blood oxygen, heart rate and daily habits — built for living with a cardiac condition, not just measuring one.")
                .font(.system(size: 13.5, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            Spacer(minLength: 0)
        }
    }

    private var meetOxy: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Theme.accent.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    ))
                    .frame(width: 150, height: 150)
                OxyMascotView(mood: .cheer, size: 110)
            }
            .padding(.top, 12)

            Text("Meet Oxy")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text("Your companion in here. Oxy notices patterns in your readings, nudges you gently, and celebrates your consistency — never grades, never alarms. Earn Oxypoints to give Oxy new looks along the way.")
                .font(.system(size: 13.5, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            Text("Oxylittle isn't a medical device — Oxy shares observations, never medical advice.")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            Spacer(minLength: 0)
        }
    }

    private var developerNoteScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A NOTE FROM THE MAKER")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
                .tracking(0.6)

            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.surfaceElevated)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(developerInitial)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Built by \(developerName)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(developerRole)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }

            Text(developerNote)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color(uiColor: .init(red: 0.784, green: 0.816, blue: 0.847, alpha: 1)))
                .lineSpacing(4)
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )

            HStack(spacing: 10) {
                Text("✉️").font(.system(size: 15))
                Text("Real person on the other end — reach me anytime from Settings → Contact.")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Color(uiColor: .init(red: 0.784, green: 0.816, blue: 0.847, alpha: 1)))
                    .lineSpacing(1)
                Spacer(minLength: 0)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
    }

    private func advance() {
        if index == 2 {
            onFinish()
        } else {
            index += 1
        }
    }
}
