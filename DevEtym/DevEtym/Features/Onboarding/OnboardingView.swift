import SwiftUI

/// 최초 실행 시 1회 표시되는 온보딩
/// - AppStorage("hasSeenOnboarding") 플래그로 표시 여부 제어
/// - AI 생성 고지 문구 포함
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.Palette.brand)
                        .accessibilityHidden(true)
                    Text("개발 어원 사전")
                        .font(Theme.serif(28, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.Palette.text)
                    Text("개발 용어의 어원과 작명 이유를\n한국어로 풀어 설명합니다")
                        .font(Theme.sans(13, relativeTo: .body))
                        .foregroundStyle(Theme.Palette.textDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                Spacer()
                noticeCard
                startButton
            }
            .padding(20)
        }
    }

    private var noticeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("AI 생성 고지")
                    .font(Theme.mono(11, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Theme.Palette.accentAI)
            } icon: {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(Theme.Palette.accentAI)
                    .accessibilityHidden(true)
            }
            Text("이 앱의 모든 설명은 AI가 생성합니다. 오류가 있을 수 있으니 발견 시 상세 화면 하단의 제보 버튼으로 알려주세요.")
                .font(Theme.sans(12, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.accentAI.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var startButton: some View {
        Button {
            hasSeenOnboarding = true
        } label: {
            Text("시작하기")
                .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                .foregroundStyle(Theme.Palette.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.accent)
                )
        }
        .accessibilityLabel("앱 사용 시작하기")
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
