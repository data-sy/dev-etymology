import SwiftUI

/// 앱 루트 — TabView로 검색/북마크/히스토리/설정 4탭 구성
/// 최초 실행 시 OnboardingView를 fullScreenCover로 표시
struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
                .accessibilityLabel("검색 탭")
            BookmarkView()
                .tabItem { Label("북마크", systemImage: "bookmark") }
                .accessibilityLabel("북마크 탭")
            HistoryView()
                .tabItem { Label("히스토리", systemImage: "clock") }
                .accessibilityLabel("히스토리 탭")
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .accessibilityLabel("설정 탭")
        }
        .tint(Theme.Palette.accent)
        .toolbarBackground(Theme.Palette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(colorScheme)
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
        .environment(\.termService, PreviewTermService())
        .preferredColorScheme(.dark)
}
