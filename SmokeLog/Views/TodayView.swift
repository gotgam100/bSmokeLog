import SwiftUI

/// 아래 메뉴의 '오늘': 원형 시간표가 있는 하루 기록 화면.
/// 화살표나 달력에서 다른 날을 고를 수 있고, 오늘을 보고 있다가 자정이 지나면 새 날로 넘어간다.
struct TodayView: View {
    @Binding var day: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = Calendar.app.startOfDay(for: context.date)
            DayDetailView(day: day) { delta in
                let cal = Calendar.app
                guard let next = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: day)),
                      next <= .now else { return }
                day = next
            }
            .id(day)
            .onChange(of: today) { old, new in
                // 오늘을 보고 있었다면 새 날로 따라간다
                if day == old { day = new }
            }
        }
    }
}
