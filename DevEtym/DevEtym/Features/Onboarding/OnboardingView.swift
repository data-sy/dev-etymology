import SwiftUI

/// 최초 실행 시 1회 표시되는 온보딩
/// - AppStorage("hasSeenOnboarding") 플래그로 표시 여부 제어
/// - AI 생성 고지 문구 포함
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("개발 어원 사전")
                    .font(.largeTitle.bold())
                Text("개발 용어의 어원과 작명 이유를\n한국어로 풀어 설명합니다")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label("AI 생성 고지", systemImage: "exclamationmark.bubble")
                    .font(.subheadline.bold())
                Text("이 앱의 모든 설명은 AI가 생성합니다. 오류가 있을 수 있으니 발견 시 상세 화면 하단의 제보 버튼으로 알려주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            Button {
                hasSeenOnboarding = true
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
