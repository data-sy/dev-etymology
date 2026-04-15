import SwiftUI
import SwiftData

@main
struct DevEtymApp: App {
    let modelContainer: ModelContainer
    @MainActor
    let termService: TermService

    init() {
        do {
            modelContainer = try ModelContainer(for: Term.self, SearchHistory.self)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
        termService = TermService(modelContext: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.termService, termService)
        }
        .modelContainer(modelContainer)
    }
}
