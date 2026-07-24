import AudioToolbox
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
/// All calls no-op when Reduce Motion is on, per Apple's cross-modal
/// accessibility convention (users who dial down animation typically
/// don't want haptics either). Sounds respect the device silent switch
/// automatically because `AudioServicesPlaySystemSound` honors it.
@MainActor
enum ChatFeedback {
    /// System sound IDs (SSID). Curated from Apple's built-in library —
    /// `Tink` for send, `SMSReceived_Alert` for receive. Both are short
    /// (< 300ms) and quiet enough to fire mid-conversation without
    /// startling anyone. If a device is missing one, the call is a no-op.
    private static let sendSoundId: SystemSoundID = 1103 // "Tink" — soft ascending tick
    private static let receiveSoundId: SystemSoundID = 1003 // "SMSReceived" — familiar arrival

    /// Fired the instant the user taps Send.
    static func send() {
        guard hapticsAllowed else {
            playSound(sendSoundId)
            return
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        playSound(sendSoundId)
    }

    /// Fired when Oxy's reply finishes streaming.
    static func receive() {
        guard hapticsAllowed else {
            playSound(receiveSoundId)
            return
        }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
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
    /// "reduce feedback" for haptics too. iOS 17 added a separate
    /// `isPrefersCrossFadeTransitionsEnabled` but no dedicated
    /// reduce-haptics setting, so this is the honest proxy.
    private static var hapticsAllowed: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    private static func playSound(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
