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
        #if DEBUG
        // 타이포그래피 적용 검증용 임시 마커. 머지 전 제거.
        print("[DEVETYM-BUILD] phase=baseline-17pt · body=SF.body(17) · code*=mono17 · label=SF.subheadline(15)")
        #endif
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
