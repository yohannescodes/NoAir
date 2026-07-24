import SwiftData
import SwiftUI

/// Full-screen chat modal with Oxy (Screens v2 §A2-§A6).
///
/// Entered from the Home hero's "Ask Oxy" affordance. One conversation per
/// install — messages persist so returning to chat resumes where the user
/// left off. First entry shows the §A2 empty state with three suggested
/// prompts. Mid-conversation renders §A3 with tight-cornered mascot/user
/// bubbles and a token-stream caret while Gemini is replying.
struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthDataProvider.self) private var healthDataProvider
    let readingEnricher: ReadingEnricher

    let preferences: UserPreferences
    /// Stable UUID for the single conversation per install. Sourced from
    /// UserDefaults so it survives app-uninstall-and-reinstall by staying
    /// tied to the current SwiftData store.
    private static let conversationDefaultsKey = "oxylittle.chat.conversationId"

    @Query(sort: \ChatMessage.createdAt, order: .forward) private var allMessages: [ChatMessage]
    @Query(sort: \ReadingRecord.timestamp, order: .reverse) private var readings: [ReadingRecord]
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var journals: [JournalEntry]
    @Query(sort: \TreatmentEvent.timestamp, order: .reverse) private var treatments: [TreatmentEvent]

    @State private var conversationId: UUID = ChatView.loadOrMintConversationId()
    @State private var draft: String = ""
    @State private var isGenerating: Bool = false
    @State private var failureMessage: String?
    /// True while the cold-open context refresh (HealthKit + environment) is
    /// in flight. The header shows "loading context…" and the composer is
    /// disabled until it flips false so the first turn always has fresh
    /// grounding.
    @State private var isLoadingContext: Bool = false
    @FocusState private var composerFocused: Bool

    private let service = GeminiChatService()

    private var messages: [ChatMessage] {
        allMessages.filter { $0.conversationId == conversationId }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.stroke)
            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }
            composer
        }
        .background(Theme.background.ignoresSafeArea())
        .task { await refreshContextIfNeeded() }
    }

    /// Debounce window for the cold-open context refresh. Two minutes is
    /// long enough that a rapid re-open (user dismisses chat, opens it
    /// again) skips the round-trip, but short enough that a real cold
    /// launch always sees fresh data.
    private static let contextRefreshTTL: TimeInterval = 120
    private static let lastRefreshKey = "oxylittle.chat.contextLastRefresh"

    /// Fired once per modal open. Pulls the freshest HealthKit + environment
    /// snapshot so the very first turn has grounding.
    ///
    /// `.task` re-runs whenever ChatView's identity changes — and inside
    /// a `fullScreenCover` that happens on every present. `@State
    /// isLoadingContext` is a fresh instance each present so it cannot
    /// guard across them. Persist the last-refresh timestamp in
    /// UserDefaults instead: skip the round-trip if the last refresh
    /// was within the TTL.
    private func refreshContextIfNeeded() async {
        guard !isLoadingContext else { return }
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: Self.lastRefreshKey)
        if last > 0, now - last < Self.contextRefreshTTL {
            return
        }
        isLoadingContext = true
        async let hk: Void = healthDataProvider.refresh()
        async let enrichment = readingEnricher.enrichReading()
        let (_, freshEnrichment) = await (hk, enrichment)
        if let latest = readings.first {
            latest.apply(freshEnrichment)
            try? modelContext.save()
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
        isLoadingContext = false
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("Oxy")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(headerSubtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(headerSubtitleTint)
                    .contentTransition(.opacity)
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var headerSubtitle: String {
        if isLoadingContext { return "loading fresh context…" }
        if isGenerating { return "typing…" }
        return "powered by Gemini"
    }

    private var headerSubtitleTint: Color {
        if isLoadingContext { return Theme.textTertiary }
        if isGenerating { return Theme.textTertiary }
        return Theme.accent
    }

    // MARK: - Empty state (§A2)

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            OxyMascotView(mood: .calm, size: 78)
            Text("Ask me anything about your patterns")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("I can see your readings, notes and environment — but I'm not a doctor, so I'll keep it to what I notice.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                suggestedPrompt("Why was my SpO₂ lower this morning?")
                suggestedPrompt("What changed since my last phlebotomy?")
                suggestedPrompt("Summarize my week")
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            Spacer()
        }
    }

    private func suggestedPrompt(_ text: String) -> some View {
        Button {
            draft = text
            composerFocused = true
        } label: {
            Text(text)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(NAPressableButtonStyle())
    }

    // MARK: - Message list (§A3, §A4, §A5)

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 18, bottomTrailing: 6, topTrailing: 18),
                            style: .continuous
                        )
                        .fill(Theme.accent)
                    )
            }
        case .oxy:
            HStack(alignment: .bottom, spacing: 7) {
                OxyMascotView(mood: message.state == .failed ? .watchful : .calm, size: 26, showGlow: false)
                Group {
                    if message.state == .failed {
                        failureBubble(message)
                    } else {
                        oxyBubble(message)
                    }
                }
                Spacer(minLength: 40)
            }
        }
    }

    private func oxyBubble(_ message: ChatMessage) -> some View {
        // Long-response scroll: bubbles over ~300pt tall clip inside their
        // own ScrollView per §A5 so the composer stays visible.
        ScrollView {
            HStack(alignment: .top, spacing: 0) {
                Text(message.text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                if message.state == .streaming {
                    caret
                }
            }
        }
        .frame(maxHeight: 300)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                style: .continuous
            )
            .fill(Theme.surface)
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                style: .continuous
            )
            .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private var caret: some View {
        Rectangle()
            .fill(Theme.accent)
            .frame(width: 2, height: 14)
            .offset(x: 2)
            .transition(.opacity)
            .modifier(BlinkModifier())
    }

    private func failureBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Couldn't reach Gemini")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.error)
            Text(message.text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(uiColor: .init(red: 1.0, green: 0.69, blue: 0.69, alpha: 1)))
            HStack(spacing: 8) {
                Button("Retry") {
                    Task { await retry(failedMessage: message) }
                }
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.accent))
                Button("Dismiss") {
                    modelContext.delete(message)
                    try? modelContext.save()
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().strokeBorder(Theme.stroke, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                style: .continuous
            )
            .fill(Theme.errorSoft)
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 18, bottomLeading: 6, bottomTrailing: 18, topTrailing: 18),
                style: .continuous
            )
            .strokeBorder(Theme.error.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Composer (§A6)

    private var composer: some View {
        VStack(spacing: 0) {
            if let failureMessage {
                HStack {
                    Text("⚠ \(failureMessage)")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Theme.error)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    isGenerating ? "Oxy is replying…" : "Message Oxy…",
                    text: $draft,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.sentences)
                .focused($composerFocused)
                .disabled(isGenerating)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(sendEnabled ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1.5)
                        )
                )

                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Theme.background)
    }

    private var sendEnabled: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isGenerating
            && !isLoadingContext
    }

    @ViewBuilder
    private var sendButton: some View {
        if isGenerating {
            Button {
                // No cancel wired up yet — fake-stream lands as one chunk.
                // Kept as a visual affordance for parity with the design.
            } label: {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.textPrimary)
                    .frame(width: 11, height: 11)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.surfaceElevated))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Task { await sendCurrent() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(sendEnabled ? Theme.onAccent : Theme.textTertiary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(sendEnabled ? Theme.accent : Theme.surfaceElevated)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!sendEnabled)
        }
    }

    // MARK: - Send

    private func sendCurrent() async {
        let userText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        // Send-side feedback fires the moment the tap registers — matches
        // iMessage timing so the input feels responsive even before the
        // network turn starts.
        ChatFeedback.send()

        let userMessage = ChatMessage(conversationId: conversationId, role: .user, text: userText)
        modelContext.insert(userMessage)
        draft = ""
        failureMessage = nil

        // Placeholder streaming bubble the fake-stream fills into.
        let placeholder = ChatMessage(conversationId: conversationId, role: .oxy, text: "", state: .streaming)
        modelContext.insert(placeholder)
        try? modelContext.save()

        isGenerating = true

        do {
            let context = buildContextDigest()
            // Exclude placeholder AND the just-inserted userMessage —
            // service.send appends the current turn itself, so leaving
            // userMessage in `history` sends it twice, and Gemini gets
            // two consecutive user turns (which it collapses/ignores).
            let history = messages.filter {
                $0.id != placeholder.id
                    && $0.id != userMessage.id
                    && $0.state != .failed
            }
            let reply = try await service.send(history: history, userTurn: userText, context: context)
            await streamIntoBubble(reply, placeholder: placeholder)
            // Arrival feedback once — not per streamed chunk — so the
            // haptic doesn't jackhammer during the fake-stream.
            ChatFeedback.receive()
        } catch {
            placeholder.state = .failed
            placeholder.text = fallbackCopy(for: error)
            try? modelContext.save()
            failureMessage = "Offline or rate-limited — try again in a moment."
            ChatFeedback.error()
        }
        isGenerating = false
    }

    private func retry(failedMessage: ChatMessage) async {
        modelContext.delete(failedMessage)
        // Re-fire the last user turn.
        if let lastUser = messages.last(where: { $0.role == .user }) {
            draft = lastUser.text
            await sendCurrent()
        }
    }

    /// Reveal the reply chunk by chunk so it feels streamed. Splits by word
    /// with a short delay per chunk — no real SSE, but visually identical
    /// for chat-length replies.
    ///
    /// **Do not replace with instant paste.** The pacing is deliberate:
    /// it buys the user time to read attentively, and matches the
    /// conversational rhythm we've set elsewhere (onboarding push, chat
    /// send/receive). A "real" SSE upgrade should preserve the same
    /// perceived cadence, not shave it.
    @MainActor
    private func streamIntoBubble(_ full: String, placeholder: ChatMessage) async {
        let words = full.split(separator: " ", omittingEmptySubsequences: false)
        var built = ""
        for (index, word) in words.enumerated() {
            built += (index == 0 ? "" : " ") + String(word)
            placeholder.text = built
            try? modelContext.save()
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        placeholder.state = .complete
        placeholder.text = full
        try? modelContext.save()
    }

    // MARK: - Context digest

    /// Compact snapshot of the user's state so Oxy has grounding. Kept
    /// short so we don't blow token budgets on long histories.
    private func buildContextDigest() -> String {
        var lines: [String] = []
        lines.append("User baseline SpO2: \(preferences.baselineSpo2)% (personal zone \(preferences.personalZoneRange.lowerBound)-\(preferences.personalZoneRange.upperBound))")
        lines.append("Fluid target: \(preferences.targetMl) ml/day")

        let recentReadings = readings.prefix(10)
        if !recentReadings.isEmpty {
            lines.append("Recent readings (newest first):")
            for r in recentReadings {
                var parts: [String] = [r.timestamp.formatted(date: .abbreviated, time: .shortened)]
                if let s = r.spo2 { parts.append("SpO2 \(s)%") }
                if let p = r.pulse { parts.append("HR \(p)") }
                if let c = r.context { parts.append("ctx=\(c)") }
                lines.append("  - " + parts.joined(separator: " · "))
            }
        }
        let recentTreatments = treatments.prefix(5)
        if !recentTreatments.isEmpty {
            lines.append("Recent treatments:")
            for t in recentTreatments {
                lines.append("  - \(t.timestamp.formatted(date: .abbreviated, time: .shortened)) · \(t.type.rawValue) · \(t.note)")
            }
        }
        let recentJournals = journals.prefix(5)
        if !recentJournals.isEmpty {
            lines.append("Recent journal entries (user's own words — treat as ground truth):")
            for j in recentJournals {
                lines.append("  - [\(j.timestamp.formatted(date: .abbreviated, time: .shortened))] \(j.text)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Error copy map

    private func fallbackCopy(for error: Error) -> String {
        if let e = error as? GeminiCommentaryError {
            switch e {
            case .missingAPIKey: return "I can't chat right now — try again in a bit."
            case .requestFailed: return "Rate limit hit — too many requests right now. Give it a minute and try again."
            case .blocked: return "I can't answer that one. Try asking about your readings or patterns."
            case .invalidResponse: return "That didn't come back cleanly. Mind trying again?"
            }
        }
        return "Something went wrong. Try again in a moment."
    }

    // MARK: - Conversation id persistence

    private static func loadOrMintConversationId() -> UUID {
        if let raw = UserDefaults.standard.string(forKey: conversationDefaultsKey),
           let id = UUID(uuidString: raw) {
            return id
        }
        let fresh = UUID()
        UserDefaults.standard.set(fresh.uuidString, forKey: conversationDefaultsKey)
        return fresh
    }
}

/// One-second opacity blink for the streaming caret.
private struct BlinkModifier: ViewModifier {
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    visible.toggle()
                }
            }
    }
}
