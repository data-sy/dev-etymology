import SwiftUI

/// Theme.Typography 토큰별 ViewModifier.
///
/// 폰트만이 아니라 **lineSpacing·tracking 까지 묶어** 토큰으로 노출한다.
/// 호출부는 `.font(Theme.Typography.body)` 가 아니라 `.typoBody()` 로 적용해야
/// 디자인 시스템 단일 진입점이 보장된다.
///
/// 디버그 시 토큰을 한 곳에서 튜닝하면 전 화면이 따라온다.
extension View {

    // MARK: 타이틀

    /// 용어명 대형 / Onboarding 타이틀 (DM Serif 28)
    func typoTitleHero() -> some View {
        self.font(Theme.Typography.titleHero)
            .tracking(-0.3)
    }

    /// 탭 헤더 (DM Serif 20)
    func typoTitleTab() -> some View {
        self.font(Theme.Typography.titleTab)
            .tracking(-0.2)
    }

    // MARK: 본문 (SF)

    /// Settings 항목 라벨 (SF body 17)
    func typoBodyLarge() -> some View {
        self.font(Theme.Typography.bodyLarge)
            .tracking(-0.05)
    }

    /// 일반 본문 (SF body 17, lineSpacing 6) — Detail namingReason, Onboarding 서브
    func typoBody() -> some View {
        self.font(Theme.Typography.body)
            .lineSpacing(6)
            .tracking(-0.1)
    }

    /// Detail summary (SF body 17)
    func typoBodySub() -> some View {
        self.font(Theme.Typography.bodySub)
            .tracking(-0.1)
    }

    /// 빈 상태·안내 타이틀 (SF headline 17 semibold)
    func typoBodyEmphasis() -> some View {
        self.font(Theme.Typography.bodyEmphasis)
            .tracking(-0.1)
    }

    /// Detail etymology 강조 블록 본문 (SF body 17, lineSpacing 7)
    func typoBodyBlock() -> some View {
        self.font(Theme.Typography.bodyBlock)
            .lineSpacing(7)
            .tracking(-0.1)
    }

    /// 고지문·OFL 본문 (SF callout 16, lineSpacing 4)
    func typoBodyNotice() -> some View {
        self.font(Theme.Typography.bodyNotice)
            .lineSpacing(4)
            .tracking(-0.05)
    }

    /// 자동완성 한 줄 미리보기 (SF body 17)
    func typoBodyPreview() -> some View {
        self.font(Theme.Typography.bodyPreview)
            .tracking(-0.1)
    }

    /// 북마크 한 줄 미리보기 (SF footnote 13)
    func typoBodyPreviewSmall() -> some View {
        self.font(Theme.Typography.bodyPreviewSmall)
            .tracking(-0.05)
    }

    // MARK: 영문 코드 (DM Mono)

    /// 로딩 시 용어명 헤더 (DM Mono 20 medium)
    func typoCodeHero() -> some View {
        self.font(Theme.Typography.codeHero)
            .tracking(-0.3)
    }

    /// 리스트 행 영문 용어명 (DM Mono 17 medium)
    func typoCodeBody() -> some View {
        self.font(Theme.Typography.codeBody)
            .tracking(-0.2)
    }

    /// 검색 입력필드·히스토리 행 영문 키워드 (DM Mono 17)
    func typoCodeInput() -> some View {
        self.font(Theme.Typography.codeInput)
            .tracking(-0.2)
    }

    /// Settings 정보 행 값(버전·빌드 번호) (DM Mono 15)
    func typoCodeValue() -> some View {
        self.font(Theme.Typography.codeValue)
            .tracking(-0.1)
    }

    /// FlowChips 영문 키워드 (DM Mono 13 medium)
    func typoCodeChip() -> some View {
        self.font(Theme.Typography.codeChip)
            .tracking(-0.1)
    }

    // MARK: 뱃지 (caps lock — 자간 양수)

    /// 카테고리 뱃지 (DM Mono 12 medium, tracking 0.8) — DB·PATTERNS
    func typoBadge() -> some View {
        self.font(Theme.Typography.badge)
            .tracking(0.8)
    }

    /// AI 뱃지 (SF caption semibold, tracking 0.2) — "✦ AI 생성"
    func typoBadgeAI() -> some View {
        self.font(Theme.Typography.badgeAI)
            .tracking(0.2)
    }

    // MARK: 한글 라벨 (SF)

    /// 액션 버튼·강조 라벨 — 북마크·공유·AI 생성 고지 (SF callout 16 medium)
    func typoCodeAction() -> some View {
        self.font(Theme.Typography.codeAction)
            .tracking(-0.05)
    }

    /// Settings SECTION 헤더 (SF subheadline 15 medium, uppercase tracking)
    func typoSectionHeader() -> some View {
        self.font(Theme.Typography.sectionHeader)
            .tracking(0.6)
    }

    /// 힌트·서브타이틀·empty (SF subheadline 15)
    func typoLabel() -> some View {
        self.font(Theme.Typography.label)
            .tracking(-0.05)
    }

    /// 섹션 라벨·상대시간·보조 버튼 (SF caption 12, uppercase tracking)
    func typoCaption() -> some View {
        self.font(Theme.Typography.caption)
            .tracking(0.4)
    }
}
