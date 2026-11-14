import Foundation
import SwiftData

/// 합계·통계에서 빼기로 한 날 (여행, 아픈 날처럼 평소와 다른 날).
/// 기록은 그대로 두고, 평균·합계·차트 계산에서만 그 날을 뺀다. 달력에서 꾹 눌러 켜고 끈다.
@Model
final class ExcludedDay {
    /// 그 날 0시 (iCloud 동기화를 위해 기본값이 있어야 한다)
    var day: Date = Date.now

    init(day: Date) {
        self.day = Calendar.app.startOfDay(for: day)
    }
}

extension ExcludedDay {
    /// 제외한 날들을 0시 기준 집합으로 (조회 결과를 계산에 쓰기 좋게)
    static func days(_ items: [ExcludedDay]) -> Set<Date> {
        Set(items.map { Calendar.app.startOfDay(for: $0.day) })
    }

    /// 합계 제외를 켜고 끈다. 켜면 true.
    @MainActor
    @discardableResult
    static func toggle(_ day: Date, in context: ModelContext) -> Bool {
        let start = Calendar.app.startOfDay(for: day)
        let existing = (try? context.fetch(FetchDescriptor<ExcludedDay>(predicate: #Predicate { $0.day == start }))) ?? []
        if existing.isEmpty {
            context.insert(ExcludedDay(day: start))
            return true
        }
        for item in existing { context.delete(item) }
        return false
    }
}
