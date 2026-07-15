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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(readingEnricher: readingEnricher)
                .tint(Theme.accent)
                .environment(healthKitService)
                .environment(healthDataProvider)
        }
        .modelContainer(sharedModelContainer)
    }
}
