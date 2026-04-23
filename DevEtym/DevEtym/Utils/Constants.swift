import Foundation

enum Constants {
    /// 오류 제보 수신 이메일
    static let reportEmail = "devetym@gmail.com"
    /// Anthropic API 공식 모델 ID — 변경 시 https://docs.anthropic.com 확인
    static let claudeModel = "claude-sonnet-4-6"
    /// Claude API 타임아웃 (초)
    static let apiTimeout: TimeInterval = 30
    /// 자동완성 디바운스 (밀리초)
    static let autocompleteDebounceMs: Int = 300
    /// 최근 검색 표시 개수
    static let recentSearchLimit: Int = 5
    /// 데이터 수집 동의 여부 UserDefaults 키
    static let analyticsConsentKey = "analyticsConsent"
    /// 데이터 수집 동의 여부를 사용자에게 이미 물었는지 UserDefaults 키
    static let analyticsConsentAskedKey = "analyticsConsentAsked"
    /// 개인정보 처리방침 공개 URL (GitHub Pages)
    static let privacyPolicyURL = "https://data-sy.github.io/dev-etymology/privacy-policy/"
}
