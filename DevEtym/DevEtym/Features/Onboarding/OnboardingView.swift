import SwiftUI

/// 최초 실행 시 1회 표시되는 온보딩
///
/// 2페이지 구성:
/// 1) 앱 소개 + AI 생성 고지
/// 2) 데이터 수집 동의 (PIPA 옵트인)
///
/// "허용 안 함"을 선택해도 온보딩은 완료되어 앱에 진입할 수 있으며
/// consentGiven만 false로 유지된다.
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Environment(\.analyticsService) private var analyticsService
    @State private var selectedPage: Int = 0

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            TabView(selection: $selectedPage) {
                introPage
                    .tag(0)
                consentPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    // MARK: - 페이지 1: 인트로

    private var introPage: some View {
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
                    .font(Theme.sans(15, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Spacer()
            aiNoticeCard
            nextButton
        }
        .padding(20)
        .padding(.bottom, 40) // page indicator 공간 확보
    }

    private var aiNoticeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("AI 생성 고지")
                    .font(Theme.mono(12, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(Theme.Palette.accentAI)
            } icon: {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(Theme.Palette.accentAI)
                    .accessibilityHidden(true)
            }
            Text("이 앱의 모든 설명은 AI가 생성합니다. 오류가 있을 수 있으니 발견 시 상세 화면 하단의 제보 버튼으로 알려주세요.")
                .font(Theme.sans(14, relativeTo: .footnote))
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

    private var nextButton: some View {
        Button {
            withAnimation { selectedPage = 1 }
        } label: {
            Text("다음")
                .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                .foregroundStyle(Theme.Palette.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.accent)
                )
        }
        .accessibilityLabel("다음 페이지로 이동")
    }

    // MARK: - 페이지 2: 데이터 수집 동의

    private var consentPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.Palette.accent)
                    .accessibilityHidden(true)
                Text("데이터 수집 동의")
                    .font(Theme.serif(24, relativeTo: .title))
                    .foregroundStyle(Theme.Palette.text)
                Text("번들 사전 확장 우선순위에 반영하기 위해\n익명 이용 데이터를 수집합니다")
                    .font(Theme.sans(13, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            consentDetailCard
            privacyPolicyLink
            Spacer(minLength: 8)
            consentButtons
        }
        .padding(20)
        .padding(.bottom, 40)
    }

    private var consentDetailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            consentItem(label: "검색 키워드·시각", detail: "예: mutex, 2026-04-21T14:32:10Z")
            consentItem(label: "검색 결과 유형", detail: "번들 / AI / 미검색 / 오타")
            consentItem(label: "API 오류 유형", detail: "timeout, network_error 등")
            consentItem(label: "익명 디바이스 식별자", detail: "Firebase App Instance ID (재설치 시 변경)")
            Divider().background(Theme.Palette.border)
            Text("이름·이메일·위치·광고 식별자는 수집하지 않습니다. 동의는 설정에서 언제든 철회할 수 있습니다.")
                .font(Theme.sans(12, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.textDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func consentItem(label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.mono(11, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(Theme.Palette.text)
            Text(detail)
                .font(Theme.sans(11, relativeTo: .caption))
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var privacyPolicyLink: some View {
        if let url = URL(string: AppConfig.privacyPolicyURL) {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Text("개인정보 처리방침 전문 보기")
                        .font(Theme.sans(12, relativeTo: .footnote))
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Theme.Palette.accent)
            }
            .accessibilityLabel("개인정보 처리방침 전문을 브라우저에서 열기")
        }
    }

    private var consentButtons: some View {
        VStack(spacing: 10) {
            Button {
                completeOnboarding(consent: true)
            } label: {
                Text("허용")
                    .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.accent)
                    )
            }
            .accessibilityLabel("데이터 수집 허용하고 앱 시작")

            Button {
                completeOnboarding(consent: false)
            } label: {
                Text("허용 안 함")
                    .font(Theme.mono(13, weight: .medium, relativeTo: .body))
                    .foregroundStyle(Theme.Palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Palette.border, lineWidth: 1)
                    )
            }
            .accessibilityLabel("데이터 수집 허용 안 하고 앱 시작")
        }
    }

    // MARK: - 동의 저장 및 온보딩 완료

    private func completeOnboarding(consent: Bool) {
        analyticsService.consentGiven = consent
        UserDefaults.standard.set(true, forKey: Constants.analyticsConsentAskedKey)
        hasSeenOnboarding = true
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
