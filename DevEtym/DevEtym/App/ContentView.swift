import SwiftUI

/// 앱 루트 — TabView로 검색/북마크/히스토리 3탭 구성
/// 최초 실행 시 OnboardingView를 fullScreenCover로 표시
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
            BookmarkView()
                .tabItem { Label("북마크", systemImage: "bookmark") }
            HistoryView()
                .tabItem { Label("히스토리", systemImage: "clock") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { hasSeenOnboarding = !$0 }
        )) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.termService, MockTermService())
}
