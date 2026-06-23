import Foundation

/// 앱 내부 로직 상수 (타임아웃·리밋·UserDefaults 키 등).
/// 외부 접점(이메일·공개 URL 등)은 AppConfig.swift에 둔다.
/// nonisolated — 순수 상수 모음이라 어디서든(액터 격리 무관) 읽을 수 있어야 한다
/// (예: ClaudeAPIService의 nonisolated init 기본 인자).
nonisolated enum Constants {
    /// Anthropic API 공식 모델 ID — 변경 시 https://docs.anthropic.com 확인
    static let claudeModel = "claude-sonnet-4-6"
    /// 백엔드 프록시 base URL. 앱은 Anthropic에 직접 호출하지 않고 이 프록시를 경유한다.
    /// 키는 앱에 없고 프록시 서버 시크릿에만 존재한다.
    static let proxyBaseURL = "https://devetym-proxy.data-sy-2.workers.dev"
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
