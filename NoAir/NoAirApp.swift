import SwiftUI
import SwiftData

@main
struct NoAirApp: App {
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
            ContentView()
                .preferredColorScheme(.dark)
                .tint(.mint)
        }
        .modelContainer(sharedModelContainer)
    }
}
