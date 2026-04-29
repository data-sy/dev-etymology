import Foundation

/// 앱 내부 로직 상수 (타임아웃·리밋·UserDefaults 키 등).
/// 외부 접점(이메일·공개 URL 등)은 AppConfig.swift에 둔다.
enum Constants {
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
}
