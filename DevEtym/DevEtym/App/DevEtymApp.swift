import SwiftUI
import SwiftData
import FirebaseCore

@main
struct DevEtymApp: App {
    let modelContainer: ModelContainer
    @MainActor
    let termService: TermService
    @MainActor
    let analyticsService: AnalyticsService

    init() {
        FirebaseApp.configure()
        do {
            modelContainer = try ModelContainer(for: Term.self, SearchHistory.self)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
        let analytics = AnalyticsService()
        analyticsService = analytics
        termService = TermService(
            modelContext: modelContainer.mainContext,
            analyticsService: analytics
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.termService, termService)
                .environment(\.analyticsService, analyticsService)
        }
        .modelContainer(modelContainer)
    }
}
