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

    /// 앱스토어 스크린샷용. `-screenshotData` 실행 인자로 켠다. 이미 데이터가 있으면 건너뛴다.
    /// 연초만, 한 달 남짓. 평일·주말 생활 패턴이 보이고 최근으로 올수록 조금씩 줄어든다.
    /// 같은 결과가 나오도록 고정된 난수를 쓴다.
    @MainActor
    static func seedScreenshot(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<SmokeEntry>())) ?? 0
        guard existing == 0 else { return }
        var rng = SeededRandom(seed: 20261115)
        let cal = Calendar.app
        let today = cal.startOfDay(for: .now)
        // (시:분, 메모, 나올 확률 %)
        let weekday: [(Int, Int, String, Int)] = [
            (7, 40, "", 85), (8, 25, "출근길", 90), (10, 20, "커피 마시고", 75), (11, 50, "", 45),
            (13, 5, "점심 먹고", 95), (14, 40, "", 55), (15, 50, "회의 끝나고", 70), (17, 10, "", 50),
            (18, 40, "퇴근길", 90), (20, 10, "저녁 먹고", 85), (21, 40, "", 70), (23, 0, "", 60),
        ]
        let weekend: [(Int, Int, String, Int)] = [
            (9, 50, "", 85), (11, 20, "커피 마시고", 80), (13, 30, "점심 먹고", 90), (15, 10, "", 70),
            (16, 50, "", 60), (18, 30, "", 65), (20, 0, "저녁 먹고", 85), (21, 50, "", 75), (23, 30, "", 55),
        ]
        // 영어로 실행하면 메모도 영어로 (영문 스크린샷용)
        let english: [String: String] = [
            "출근길": "Commute", "커피 마시고": "With coffee", "점심 먹고": "After lunch",
            "회의 끝나고": "After a meeting", "퇴근길": "Heading home", "저녁 먹고": "After dinner",
        ]
        let useEnglish = AppLanguage.current == .en
        func insert(day: Date, upTo limit: Date?, trend: Int) {
            let isWeekend = cal.isDateInWeekend(day)
            for (h, m, memo, chance) in (isWeekend ? weekend : weekday) {
                // 오래된 날일수록 조금 더 자주 (trend 0~15)
                guard Int(rng.next() % 100) < min(100, chance + trend) else { continue }
                let jitter = Int(rng.next() % 31) - 15
                let minute = max(0, min(24 * 60 - 1, h * 60 + m + jitter))
                let time = day.addingTimeInterval(TimeInterval(minute * 60))
                if let limit, time > limit { continue }
                let keepMemo = !memo.isEmpty && rng.next() % 3 == 0
                let text = useEnglish ? (english[memo] ?? memo) : memo
                context.insert(SmokeEntry(timestamp: time, memo: keepMemo ? text : ""))
            }
        }
        // 지난달 1일부터 채워서 '지난달 평균'도 온전히 나오게
        let thisMonth = cal.dateInterval(of: .month, for: today)?.start ?? today
        let lastMonth = cal.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth
        let span = cal.dateComponents([.day], from: lastMonth, to: today).day ?? 35
        for offset in stride(from: span, through: 1, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            insert(day: day, upTo: nil, trend: offset / 3)
        }
        insert(day: today, upTo: .now.addingTimeInterval(-12 * 60), trend: 0)
        try? context.save()
    }

    /// 앱스토어 스크린샷용. 첫 종류(연초)만 남기고 나머지 종류는 지운다.
    @MainActor
    static func keepOnlyFirstKind(in context: ModelContext) {
        let kinds = (try? context.fetch(FetchDescriptor<SmokeKind>(sortBy: [SortDescriptor(\.order)]))) ?? []
        for kind in kinds.dropFirst() { context.delete(kind) }
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

/// 항상 같은 순서를 내는 난수 (SplitMix64)
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
#endif
