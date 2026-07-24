import SwiftUI
import SwiftData

@main
struct NoAirApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appNotificationDelegate

    @State private var healthKitService: HealthKitService
    @State private var healthDataProvider: HealthDataProvider
    private let readingEnricher: ReadingEnricher

    init() {
        let service = HealthKitService()
        _healthKitService = State(initialValue: service)
        _healthDataProvider = State(initialValue: HealthDataProvider(healthKit: service))
        readingEnricher = ReadingEnricher(healthKitService: service)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ReadingRecord.self,
            VentilationSession.self,
            TreatmentEvent.self,
            LabResultRecord.self,
            UserPreferences.self,
            DailyCheckIn.self,
            HydrationLog.self,
            IMTSession.self,
            JournalEntry.self,
            ChatMessage.self,
            GeneratedInsight.self,
            OxypointsLedger.self,
            CosmeticItem.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // First attempt: open the store as-is. Succeeds when the on-disk
        // schema matches the current model set (fresh install, or a build
        // where no schema-affecting change landed since last launch).
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            #if DEBUG
            print("[Oxylittle] ModelContainer init failed: \(error). Attempting recovery by wiping the on-disk store.")
            #endif
        }

        // Recovery path: the model set drifted from what's on disk (schema
        // mismatch after a model rename/reshape). We don't ship a
        // SchemaMigrationPlan yet, so nuke the store files and try again.
        // Safe pre-TestFlight since no user data is live; before we ship
        // we MUST replace this branch with a proper migration plan.
        Self.wipePersistedStore()
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Second failure means something structural (disk full, model
            // schema itself is invalid). No safe recovery — surface a real
            // error rather than the confusing "invalid reuse" cascade.
            fatalError("Could not create ModelContainer after wipe: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(readingEnricher: readingEnricher)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .environment(healthKitService)
                .environment(healthDataProvider)
        }
        .modelContainer(sharedModelContainer)
    }

    /// Delete the default SwiftData store files so a fresh ModelContainer
    /// can open cleanly. Handles the .sqlite plus the -wal/-shm sidecars
    /// SwiftData writes alongside it. Errors are logged in DEBUG and
    /// otherwise swallowed — if a file doesn't exist there's nothing to
    /// wipe.
    private static func wipePersistedStore() {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let candidateNames = [
            "default.store",
            "default.store-wal",
            "default.store-shm",
        ]
        for name in candidateNames {
            let url = appSupport.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    #if DEBUG
                    print("[Oxylittle] Wiped store file: \(name)")
                    #endif
                } catch {
                    #if DEBUG
                    print("[Oxylittle] Failed to wipe \(name): \(error)")
                    #endif
                }
            }
        }
    }
}
