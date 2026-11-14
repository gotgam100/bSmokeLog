import Foundation
import SwiftData
import UserNotifications

/// 일요일 저녁 8시에 한 줄로 이번 주를 알려준다(설정에서 켤 때만).
/// 알림 내용은 예약할 때 정해지므로, 앱을 열거나 기록이 바뀔 때마다 다시 계산해서 예약한다.
enum WeeklySummary {
    private static let requestID = "weeklySummary"
    private static let hour = 20

    static var isEnabled: Bool {
        AppStore.defaults.bool(forKey: AppStore.Key.weeklySummary)
    }

    /// 켤 때 알림 권한을 묻는다. 거절하면 false.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    @MainActor
    static func reschedule(context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard isEnabled, let fireDate = nextSundayEvening(after: .now) else { return }

        let content = UNMutableNotificationContent()
        content.title = L("이번 주")
        content.body = message(context: context, until: fireDate)

        let comps = Calendar.app.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
    }

    private static func nextSundayEvening(after date: Date) -> Date? {
        Calendar.app.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: 0, weekday: 1),
            matchingPolicy: .nextTime
        )
    }

    /// "이번 주 하루 평균 8.3개비, 지난주와 비슷해요."
    @MainActor
    static func message(context: ModelContext, until fireDate: Date) -> String {
        let cal = Calendar.app
        let sunday = cal.startOfDay(for: fireDate)
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: sunday),
              let prevStart = cal.date(byAdding: .day, value: -7, to: weekStart) else {
            return L("이번 주 기록을 확인해 보세요.")
        }
        // 지난 2주치만 읽고, 첫 기록 날짜는 하나만 따로 읽는다
        let since = prevStart
        let all = (try? context.fetch(FetchDescriptor<SmokeEntry>(
            predicate: #Predicate { $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp)]
        ))) ?? []
        var firstDescriptor = FetchDescriptor<SmokeEntry>(sortBy: [SortDescriptor(\.timestamp)])
        firstDescriptor.fetchLimit = 1
        guard let first = (try? context.fetch(firstDescriptor))?.first.map({ cal.startOfDay(for: $0.timestamp) }) else {
            return L("이번 주에는 기록이 없어요.")
        }

        func average(from start: Date, to end: Date) -> Double? {
            let from = max(start, first)
            let today = min(cal.startOfDay(for: .now), end)
            guard from <= today else { return nil }
            let days = (cal.dateComponents([.day], from: from, to: today).day ?? 0) + 1
            let until = cal.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
            let count = all.filter { $0.timestamp >= from && $0.timestamp < until }.count
            return Double(count) / Double(max(days, 1))
        }

        guard let now = average(from: weekStart, to: sunday) else {
            return L("이번 주에는 기록이 없어요.")
        }
        var text = L("이번 주 하루 평균 %.1f개비", now)
        if let prev = average(from: prevStart, to: cal.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart) {
            let diff = now - prev
            if abs(diff) < 0.3 {
                text += L(", 지난주와 비슷해요.")
            } else {
                text += diff < 0 ? L(", 지난주보다 하루 %.1f개비 적어요.", abs(diff)) : L(", 지난주보다 하루 %.1f개비 많아요.", abs(diff))
            }
        } else {
            text += "."
        }
        return text
    }
}
