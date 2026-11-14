import SwiftUI
import SwiftData

extension Color {
    /// 경고색 대신 차분한 톤을 쓴다.
    static let brand = Color.teal
}

extension Calendar {
    /// 설정의 '한 주의 시작'(1 = 일요일, 2 = 월요일)을 반영한다.
    /// 매번 새로 만들면 느려서(설정을 읽고 달력을 새로 만듦) 한 번 만들어 두고,
    /// 언어·한 주의 시작·시간대가 바뀌었을 때만 다시 만든다.
    static var app: Calendar {
        let weekday = UserDefaults.standard.integer(forKey: "firstWeekday") == 2 ? 2 : 1
        let locale = Locale.app
        let tz = TimeZone.current
        if let cached = AppCalendarCache.calendar,
           cached.firstWeekday == weekday, cached.locale == locale, cached.timeZone == tz {
            return cached
        }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.timeZone = tz
        cal.firstWeekday = weekday
        AppCalendarCache.calendar = cal
        return cal
    }

    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

/// "1시간 20분", "35분" 형태
func durationText(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds / 60))
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return L("%d분", m) }
    if m == 0 { return L("%d시간", h) }
    return L("%d시간 %d분", h, m)
}

/// "방금 전", "12분 전", "2시간 5분 전", "3일 전"
func elapsedText(from date: Date, to now: Date) -> String {
    let seconds = now.timeIntervalSince(date)
    if seconds < 60 { return L("방금 전") }
    if seconds >= 86_400 { return L("%d일 전", Int(seconds / 86_400)) }
    return L("%@ 전", durationText(seconds))
}

/// 0~23 → "오전 9시", "오후 3시"
func hourLabel(_ hour: Int) -> String {
    let date = Calendar.app.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    return date.formatted(Date.FormatStyle(locale: .app).hour())
}

enum AppCalendarCache {
    nonisolated(unsafe) static var calendar: Calendar?
}

#if DEBUG
enum SampleData {
    /// 시뮬레이터 확인용. `-seedSampleData` 실행 인자로 켠다. 이미 데이터가 있으면 건너뛴다.
    @MainActor
    static func seed(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<SmokeEntry>())) ?? 0
        guard existing == 0 else { return }
        let cal = Calendar.app
        let today = cal.startOfDay(for: .now)
        let memos = ["커피 마시고", "점심 먹고", "회의 끝나고", "출근길", ""]
        for offset in 1...45 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            for _ in 0..<Int.random(in: 5...14) {
                let minute = Int.random(in: (7 * 60)...(24 * 60 - 1))
                let memo = Int.random(in: 0..<3) == 0 ? (memos.randomElement() ?? "") : ""
                context.insert(SmokeEntry(timestamp: day.addingTimeInterval(TimeInterval(minute * 60)), memo: memo))
            }
        }
        try? context.save()
    }

    /// 시뮬레이터 확인용. 기록마다 종류를 무작위로 붙인다(연초가 가장 많게).
    @MainActor
    static func randomizeKinds(in context: ModelContext) {
        let kinds = (try? context.fetch(FetchDescriptor<SmokeKind>(sortBy: [SortDescriptor(\.order)]))) ?? []
        guard !kinds.isEmpty else { return }
        let entries = (try? context.fetch(FetchDescriptor<SmokeEntry>())) ?? []
        for entry in entries {
            let roll = Int.random(in: 0..<10)
            entry.kind = roll < 6 ? kinds[0] : roll < 9 ? kinds[min(1, kinds.count - 1)] : kinds[min(2, kinds.count - 1)]
        }
        try? context.save()
    }
}
#endif
