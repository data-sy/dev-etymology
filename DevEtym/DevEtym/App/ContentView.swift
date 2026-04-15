import SwiftUI

/// Phase 1에서는 앱 진입점만 확보. 실제 탭바 구성은 Phase 3(Agent B)에서 작성된다
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("개발 어원 사전")
                .font(.title2.bold())
            Text("Phase 1 foundation ready")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
