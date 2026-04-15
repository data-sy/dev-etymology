import Foundation

enum Constants {
    /// 오류 제보 수신 이메일
    static let reportEmail = "devetym@gmail.com"
    /// Anthropic API 공식 모델 ID — 변경 시 https://docs.anthropic.com 확인
    static let claudeModel = "claude-sonnet-4-5-20250514"
    /// Claude API 타임아웃 (초)
    static let apiTimeout: TimeInterval = 30
    /// 자동완성 디바운스 (밀리초)
    static let autocompleteDebounceMs: Int = 300
    /// 최근 검색 표시 개수
    static let recentSearchLimit: Int = 5
}
