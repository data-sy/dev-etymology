import Foundation

/// 익명 기기 식별자 — 백엔드 프록시의 기기당 일일 호출 한도(③)에만 사용한다.
///
/// 설계 메모:
/// - 분석(Analytics) 동의 여부와 무관하게 항상 값이 있어야 검색이 막히지 않는다.
///   그래서 동의 게이트되는 Firebase App Instance ID가 아니라, 이 용도 전용 UUID를
///   UserDefaults에 1회 생성·보관한다.
/// - 앱 삭제 시 초기화되며, 비용 방어용 rate limit엔 그 정도 안정성이면 충분하다.
/// - 분석 식별자를 프록시에 보내지 않으므로 관심사도 분리된다.
/// nonisolated — ClaudeAPIService의 nonisolated init에서 기본 인자로 호출되므로
/// (프로젝트가 MainActor-by-default라) 액터 격리를 명시적으로 벗어난다.
/// UserDefaults 접근은 스레드 안전하다.
nonisolated enum DeviceIdentifier {
    static let storageKey = "proxyDeviceId"

    /// 현재 기기의 익명 식별자. 없으면 생성하여 저장한 뒤 반환한다.
    static func current(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: storageKey), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: storageKey)
        return generated
    }
}
