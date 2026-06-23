import Foundation

/// 앱 바깥 세계(메일·URL·외부 리소스)와의 접점 설정값을 한 곳에 모은다.
///
/// - 출시 전 실제 값으로 교체가 필요한 항목에는 `// TODO(태그):` 주석을 달아 둔다.
///   출시 점검 시 `grep "TODO(" DevEtym` 으로 한 번에 체크할 수 있다.
/// - 내부 로직 상수(타임아웃·리밋·UserDefaults 키 등)는 Constants.swift에 남긴다.
enum AppConfig {
    static let supportEmail = "oddmuffinstudio@gmail.com"

    /// 개인정보 처리방침 공개 URL (GitHub Pages)
    static let privacyPolicyURL = "https://data-sy.github.io/dev-etymology/privacy-policy/"

    // 향후 추가 후보: appStoreID(리뷰 요청 딥링크), marketingURL, supportSiteURL 등
}
