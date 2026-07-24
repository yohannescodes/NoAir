import AudioToolbox
import AVFoundation
import UIKit

/// Haptic + sound feedback for the Chat modal — makes the exchange feel
/// conversational and familiar (iMessage-style tactile hits) rather than
/// silent LLM UI.
///
/// - `send()` fires immediately when the user taps send. Light impact +
///   short "sent" system sound.
/// - `receive()` fires once when Oxy's reply lands (i.e. streaming
///   completes). Soft impact + "received" system sound so the two turns
///   feel distinct.
/// - `error()` fires when a turn fails. Warning haptic, no sound —
///   Oxylittle's voice rule (Design System §9) forbids alarm cues on
///   soft failures.
///
/// Reduce Motion silences **haptics only** — sounds still play so
/// low-vision users who dial down motion still get a chat cue. The
/// device silent switch always silences `AudioServicesPlaySystemSound`
/// itself; that's a hardware convention we don't override.
///
/// **Simulator note:** haptics are hardware — the iOS Simulator has no
/// Taptic Engine and will always be silent for `send/receive/error`.
/// Test on device. Sounds *do* work in the simulator, routed through the
/// Mac's default output.
@MainActor
enum ChatFeedback {
    /// Configured on first use. Ambient + mixWithOthers so we play over
    /// music without pausing it, and honor the silent switch. Idempotent.
    private static var audioSessionConfigured = false

    /// System sound IDs. `1004` (SentMessage) and `1003` (ReceivedMessage)
    /// are the canonical iMessage-parity SSIDs — short, distinct, and
    /// present on every iOS version. If a device is missing one, the call
    /// is a no-op.
    private static let sendSoundId: SystemSoundID = 1004
    private static let receiveSoundId: SystemSoundID = 1003

    /// Fired the instant the user taps Send.
    static func send() {
        configureAudioSessionIfNeeded()
        if hapticsAllowed {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
        playSound(sendSoundId)
    }

    /// Fired when Oxy's reply finishes streaming.
    static func receive() {
        configureAudioSessionIfNeeded()
        if hapticsAllowed {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.7)
        }
        playSound(receiveSoundId)
    }

    /// Fired when a chat turn errors out.
    static func error() {
        guard hapticsAllowed else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    // MARK: - Private

    /// UIKit exposes reduce-motion via UIAccessibility; we treat it as
    /// "reduce feedback" for haptics but never for sounds.
    private static var hapticsAllowed: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    /// Set up an ambient audio session once. Without this, apps that never
    /// otherwise touch AVAudioSession sometimes get zero output from
    /// `AudioServicesPlaySystemSound` — the session is inactive and the
    /// sound is silently dropped. `.ambient + .mixWithOthers` means we
    /// coexist with the user's music and respect the ringer switch.
    private static func configureAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        audioSessionConfigured = true
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("[ChatFeedback] AVAudioSession config failed: \(error)")
            #endif
        }
    }

    private static func playSound(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
