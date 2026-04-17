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

        // MARK: - 진단 로그 (문제 해결 후 제거)
        #if DEBUG
        Self.runDiagnostics()
        #endif
    }

    #if DEBUG
    @MainActor
    private static func runDiagnostics() {
        print("──────── DevEtym 진단 시작 ────────")

        // 1. 번들 DB 로딩 확인
        let db = BundleDBService()
        let terms = db.autocomplete(prefix: "")
        print("📦 [번들 DB] terms.json 로드 성공? → 자동완성용 데이터: \(terms.count)개")
        if let mutex = db.search(keyword: "mutex") {
            print("   ✅ 'mutex' 검색 성공: category=\(mutex.category), aliases=\(mutex.aliases)")
        } else {
            print("   ❌ 'mutex' 검색 실패 — terms.json이 번들에 포함 안 됐을 가능성")
        }

        // 2. API 키 확인
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String
        if let key = apiKey, !key.isEmpty, !key.hasPrefix("$(") {
            print("🔑 [API 키] 존재 (\(key.prefix(10))...)")
        } else if let key = apiKey, key.hasPrefix("$(") {
            print("🔑 [API 키] ❌ 변수 치환 안 됨 — xcconfig 미연결: '\(key)'")
        } else {
            print("🔑 [API 키] ❌ 비어있거나 없음 — Config.xcconfig 확인 필요")
        }

        // 3. SwiftData 스키마 확인
        do {
            let container = try ModelContainer(for: Term.self, SearchHistory.self)
            let context = container.mainContext
            let count = (try? context.fetchCount(FetchDescriptor<Term>())) ?? -1
            print("💾 [SwiftData] Term 개수: \(count) — 스키마 정상")
        } catch {
            print("💾 [SwiftData] ❌ ModelContainer 생성 실패: \(error)")
            print("   → 시뮬레이터 앱 삭제 후 재설치 필요 (category 필드 마이그레이션)")
        }

        print("──────── DevEtym 진단 끝 ────────")
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.termService, termService)
        }
        .modelContainer(modelContainer)
    }
}
