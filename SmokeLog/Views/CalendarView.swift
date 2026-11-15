import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("firstWeekday") private var firstWeekday = 1
    /// 하루 기준선(0 = 끔). 넘으면 달력 숫자 색만 살짝 바뀐다.
    @AppStorage(AppStore.Key.dailyLimit, store: AppStore.defaults) private var dailyLimit = 0

    @State private var month = Calendar.app.startOfMonth(for: .now)
    @Environment(\.openDay) private var openDay
    @State private var toast: ToastInfo?
    @State private var addCount = 0
    /// 합계에서 뺀 날들 (달력 표시용)
    @Query private var excludedDays: [ExcludedDay]

    private var cal: Calendar { .app }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let now = timeline.date
                ScrollView {
                    VStack(spacing: 14) {
                        ScreenTitle(title: L("달력")) {
                            if month != cal.startOfMonth(for: now) {
                                Button(L("이번 달")) {
                                    withAnimation { month = cal.startOfMonth(for: now) }
                                }
                                .font(.subheadline.weight(.medium))
                            }
                            SettingsButton()
                        }

                        MonthSummary(month: month, now: now) {
                            openDay(now)
                        }

                        VStack(spacing: 8) {
                            monthHeader(now: now)
                            MonthGrid(
                                month: month,
                                now: now,
                                dailyLimit: dailyLimit,
                                excluded: ExcludedDay.days(excludedDays),
                                onTap: { day in
                                    if day <= now { openDay(day) }
                                },
                                onAdd: add(to:),
                                onRemove: removeLatest(on:),
                                onToggleExclude: toggleExclude
                            )
                            .id(firstWeekday)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                        Text(L("날짜를 누르면 그날 기록 보기 · 꾹 누르면 추가, 삭제, 합계 제외"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    .padding(.top, ScreenTitle<EmptyView>.topPadding)
                    .padding(.bottom, BottomTabBar.contentInset)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if let toast {
                    ToastView(info: toast) { undo(toast) }
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sensoryFeedback(trigger: addCount) { _, _ in hapticsEnabled ? .increase : nil }
        }
    }

    // MARK: - 하위 뷰

    private func monthHeader(now: Date) -> some View {
        HStack {
            Button { shiftMonth(-1, now: now) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            Spacer()
            Text(month, format: .dateTime.year().month(.wide))
                .font(.headline)
            Spacer()
            Button { shiftMonth(1, now: now) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .disabled(month >= cal.startOfMonth(for: now))
        }
    }

    // MARK: - 데이터

    /// 그 날의 기록만 저장소에서 바로 읽는다 (전체 기록을 들고 있지 않음)
    private func entries(on day: Date) -> [SmokeEntry] {
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<SmokeEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 동작

    /// 오늘이면 지금 시각, 지난 날이면 그 날의 '지금과 같은 시각'으로 한 개비를 더한다.
    private func add(to day: Date) {
        let now = Date.now
        let start = cal.startOfDay(for: day)
        let time: Date
        if cal.isDate(day, inSameDayAs: now) {
            time = now
        } else {
            let sinceMidnight = now.timeIntervalSince(cal.startOfDay(for: now))
            time = start.addingTimeInterval(sinceMidnight)
        }
        let entry = SmokeEntry(timestamp: time, kind: KindStore.defaultKind(context))
        withAnimation(.snappy) { context.insert(entry) }
        addCount += 1
        let label = cal.isDate(day, inSameDayAs: now) ? "" : "\(shortDate(start)) "
        let id = entry.persistentModelID
        showToast(ToastInfo(message: L("%@에 기록했어요", "\(label)\(timeText(time))")) { [context] in
            withAnimation(.snappy) { KindStore.deleteEntries([id], in: context) }
        })
    }

    /// 그 날의 가장 늦은 기록 하나를 지운다. 실행 취소하면 같은 시각·메모로 되살린다.
    private func removeLatest(on day: Date) {
        guard let latest = entries(on: day).last else { return }
        let time = latest.timestamp
        let memo = latest.memo
        let kindID = latest.kind?.id
        withAnimation(.snappy) { context.delete(latest) }
        showToast(ToastInfo(message: L("%@ 기록을 삭제했어요", "\(shortDate(day)) \(timeText(time))")) { [context] in
            let kind = KindStore.kind(id: kindID, in: context)
            withAnimation(.snappy) { context.insert(SmokeEntry(timestamp: time, memo: memo, kind: kind)) }
        })
    }

    /// 그 날을 합계·통계에서 빼거나 다시 넣는다. 기록은 그대로다.
    private func toggleExclude(_ day: Date) {
        let start = cal.startOfDay(for: day)
        let nowExcluded = withAnimation(.snappy) { ExcludedDay.toggle(start, in: context) }
        showToast(ToastInfo(message: nowExcluded
                            ? L("%@ 기록을 합계에서 뺐어요", shortDate(start))
                            : L("%@ 기록을 합계에 다시 넣었어요", shortDate(start))))
    }

    private func showToast(_ info: ToastInfo) {
        withAnimation(.spring(duration: 0.3)) { toast = info }
        Task {
            // 실행 취소가 있는 알림은 조금 더 오래 보여준다.
            try? await Task.sleep(for: .seconds(info.undo == nil ? 3 : 5))
            if toast?.id == info.id {
                withAnimation { toast = nil }
            }
        }
    }

    private func undo(_ info: ToastInfo) {
        withAnimation { toast = nil }
        info.undo?()
    }

    private func shiftMonth(_ delta: Int, now: Date) {
        guard let next = cal.date(byAdding: .month, value: delta, to: month),
              next <= cal.startOfMonth(for: now) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { month = next }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: .app).month().day())
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: .app).hour().minute())
    }
}

// MARK: - 이달 요약

/// 보이는 달의 하루 평균·합계와 지난달 평균. 이번 달이면 오늘이 어제 이맘때보다 늘었는지 줄었는지도 보이고,
/// 누르면 오늘 화면으로 간다.
private struct MonthSummary: View {
    let month: Date
    let now: Date
    let onTap: () -> Void
    /// 지난달 1일부터 이달 말까지
    @Query private var entries: [SmokeEntry]
    @Query private var excludedDays: [ExcludedDay]

    init(month: Date, now: Date, onTap: @escaping () -> Void) {
        self.month = month
        self.now = now
        self.onTap = onTap
        let cal = Calendar.app
        let from = cal.date(byAdding: .month, value: -1, to: month) ?? month
        let to = cal.date(byAdding: .month, value: 1, to: month) ?? month
        _entries = Query(filter: #Predicate<SmokeEntry> { $0.timestamp >= from && $0.timestamp < to })
    }

    var body: some View {
        let cal = Calendar.app
        let isCurrent = cal.isDate(month, equalTo: now, toGranularity: .month)
        // 합계에서 뺀 날은 기록도, 날수도 세지 않는다
        let excluded = ExcludedDay.days(excludedDays)
        let counted = entries.filter { !excluded.contains(cal.startOfDay(for: $0.timestamp)) }
        let thisCount = counted.filter { $0.timestamp >= month }.count
        let prevCount = counted.count - thisCount
        // 이번 달은 오늘까지 지난 날수로, 지난 달은 그 달 날수로 나눈다
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let prevMonth = cal.date(byAdding: .month, value: -1, to: month) ?? month
        let today = cal.startOfDay(for: now)
        let days = (isCurrent ? cal.component(.day, from: now) : daysInMonth)
            - excluded.filter { $0 >= month && $0 <= today && cal.isDate($0, equalTo: month, toGranularity: .month) }.count
        let prevDays = (cal.range(of: .day, in: .month, for: prevMonth)?.count ?? 30)
            - excluded.filter { cal.isDate($0, equalTo: prevMonth, toGranularity: .month) }.count
        let average = Double(thisCount) / Double(max(days, 1))
        let prevAverage = Double(prevCount) / Double(max(prevDays, 1))

        let card = VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isCurrent ? L("이달 하루 평균") : L("%@ 하루 평균", month.formatted(Date.FormatStyle(locale: .app).month(.wide))))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(average.formatted(.number.precision(.fractionLength(1))))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(L("개비"))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L("합계 %d개비", thisCount))
                    Text(prevCount > 0 ? L("지난달 평균 %.1f개비", prevAverage) : L("지난달 기록 없음"))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 8)
            }
            if isCurrent {
                Divider()
                todayRow(today: today)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

        if isCurrent {
            Button(action: onTap) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }
}

extension MonthSummary {
    /// 오늘 개수를 어제 같은 시각까지와 비교해 얼마나 늘거나 줄었는지.
    /// 많으면 빨간 ↑, 적으면 파란 ↓, 같으면 회색 −.
    fileprivate func todayRow(today: Date) -> some View {
        let cal = Calendar.app
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86_400)
        let cutoff = now.addingTimeInterval(-86_400)
        let todayCount = entries.filter { $0.timestamp >= today }.count
        let yesterdayCount = entries.filter { $0.timestamp >= yesterday && $0.timestamp < today && $0.timestamp <= cutoff }.count
        let diff = todayCount - yesterdayCount
        let color: Color = diff > 0 ? .red : diff < 0 ? .blue : .secondary
        return HStack(spacing: 3) {
            Spacer(minLength: 0)
            Text(L("어제 이맘때보다"))
                .foregroundStyle(.secondary)
            Text("\(abs(diff))")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
            Image(systemName: diff > 0 ? "arrow.up" : diff < 0 ? "arrow.down" : "minus")
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
        .font(.footnote)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

// MARK: - 달력 그리드

private struct MonthGrid: View {
    let month: Date
    let now: Date
    let dailyLimit: Int
    /// 합계에서 뺀 날들 (0시 기준)
    let excluded: Set<Date>
    let onTap: (Date) -> Void
    let onAdd: (Date) -> Void
    let onRemove: (Date) -> Void
    let onToggleExclude: (Date) -> Void

    /// 보이는 달의 기록만 읽는다 (몇 년치가 쌓여도 한 달치만)
    @Query private var monthEntries: [SmokeEntry]

    private let cal = Calendar.app
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(month: Date, now: Date, dailyLimit: Int, excluded: Set<Date>,
         onTap: @escaping (Date) -> Void, onAdd: @escaping (Date) -> Void, onRemove: @escaping (Date) -> Void,
         onToggleExclude: @escaping (Date) -> Void) {
        self.month = month
        self.now = now
        self.dailyLimit = dailyLimit
        self.excluded = excluded
        self.onTap = onTap
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onToggleExclude = onToggleExclude
        let start = month
        let end = Calendar.app.date(byAdding: .month, value: 1, to: month) ?? month
        var descriptor = FetchDescriptor<SmokeEntry>(predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end })
        descriptor.relationshipKeyPathsForPrefetching = [\.kind]
        _monthEntries = Query(descriptor)
    }

    /// 날마다 개수와 종류별 비율(칸 테두리용)을 한 번에 센다. 종류는 설정 순서대로, 종류 없음은 맨 뒤.
    private func summarize() -> (counts: [Date: Int], slices: [Date: [KindSlice]]) {
        var perDay: [Date: [UUID?: (order: Int, color: Color, count: Int)]] = [:]
        var counts: [Date: Int] = [:]
        for e in monthEntries {
            let day = cal.startOfDay(for: e.timestamp)
            counts[day, default: 0] += 1
            let kind = e.kind
            perDay[day, default: [:]][kind?.id, default: (kind?.order ?? .max, e.color, 0)].count += 1
        }
        let slices = perDay.mapValues { kinds in
            let total = Double(kinds.values.reduce(0) { $0 + $1.count })
            return kinds.values
                .sorted { $0.order < $1.order }
                .map { KindSlice(color: $0.color, share: Double($0.count) / total) }
        }
        return (counts, slices)
    }

    var body: some View {
        let (counts, slices) = summarize()
        let days = (cal.range(of: .day, in: .month, for: month) ?? 1..<2).compactMap {
            cal.date(byAdding: .day, value: $0 - 1, to: month)
        }
        let leading = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let maxCount = max(days.map { counts[$0] ?? 0 }.max() ?? 0, 1)

        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    let isSunday = (cal.firstWeekday - 1 + index) % 7 == 0
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(isSunday ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<leading, id: \.self) { i in
                    Color.clear.frame(height: 52).id("blank-\(i)")
                }
                ForEach(days, id: \.self) { day in
                    let count = counts[day] ?? 0
                    let isToday = cal.isDate(day, inSameDayAs: now)
                    let isFuture = day > now
                    let isExcluded = excluded.contains(day)
                    Button { onTap(day) } label: {
                        DayCell(
                            day: cal.component(.day, from: day),
                            count: count,
                            isToday: isToday,
                            isFuture: isFuture,
                            isSunday: cal.component(.weekday, from: day) == 1,
                            intensity: Double(count) / Double(maxCount),
                            slices: slices[day] ?? [],
                            overLimit: dailyLimit > 0 && count > dailyLimit,
                            excluded: isExcluded
                        )
                    }
                    .buttonStyle(DayButtonStyle())
                    .disabled(isFuture)
                    .contextMenu {
                        if !isFuture {
                            Button { onAdd(day) } label: {
                                Label(L("한 개비 추가"), systemImage: "plus.circle")
                            }
                            Button(role: .destructive) { onRemove(day) } label: {
                                Label(L("한 개비 삭제"), systemImage: "minus.circle")
                            }
                            .disabled(count == 0)
                            Divider()
                            // 여행·아픈 날처럼 평소와 다른 날은 평균·합계에서 뺄 수 있다
                            Button { onToggleExclude(day) } label: {
                                Label(isExcluded ? L("합계에 포함") : L("합계 제외"),
                                      systemImage: isExcluded ? "checkmark.circle" : "circle.dashed")
                            }
                        }
                    }
                    .accessibilityLabel(Text(day, format: .dateTime.month().day()))
                    .accessibilityValue(isExcluded ? L("%d개비", count) + ", " + L("합계에서 제외") : L("%d개비", count))
                    .accessibilityHint(L("누르면 기록을 보고, 길게 누르면 추가하거나 삭제합니다"))
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}

/// 위: 날짜(배경 없음) / 아래: 개비 수 원형 배지. 둘이 섞이지 않도록 분리한다.
private struct DayCell: View {
    let day: Int
    let count: Int
    let isToday: Bool
    let isFuture: Bool
    let isSunday: Bool
    let intensity: Double
    /// 그날 종류별 비율 → 동그라미 테두리를 나눠 칠한다
    let slices: [KindSlice]
    /// 하루 기준선을 넘었으면 숫자 색만 살짝 바꾼다
    let overLimit: Bool
    /// 합계·통계에서 뺀 날: 점선 테두리에 숫자를 흐리게
    let excluded: Bool

    private var dateColor: Color {
        if isSunday { return .red }
        return isToday ? .brand : .primary
    }

    /// 개비 수는 요일과 상관없이 같은 색 (일요일 빨강은 날짜에만)
    private var countColor: Color {
        if excluded { return .secondary }
        if overLimit { return Color(red: 0.85, green: 0.1, blue: 0.15) }
        return count > 0 ? .primary : .brand
    }

    private var badgeFill: Color {
        if isFuture || excluded { return .clear }
        if count == 0 { return Color(.tertiarySystemFill) }
        return Color.brand.opacity(0.15 + 0.4 * intensity)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(dateColor)

            ZStack {
                Circle().fill(badgeFill)
                if excluded {
                    Circle().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                } else if count > 0 {
                    KindRing(slices: slices)
                } else if isToday {
                    Circle().strokeBorder(Color.brand, lineWidth: 2)
                }
                Text(count > 0 ? "\(count)" : "")
                    .font(.subheadline.weight(overLimit && !excluded ? .heavy : .semibold).monospacedDigit())
                    .strikethrough(excluded, color: .secondary)
                    .foregroundStyle(countColor)
                    .contentTransition(.numericText())
            }
            .frame(width: 32, height: 32)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .opacity(isFuture ? 0.3 : 1)
        .contentShape(Rectangle())
    }
}

struct KindSlice {
    let color: Color
    let share: Double
}

/// 동그라미 테두리를 종류 비율대로 나눠 칠한다(12시 방향부터 시계 방향).
private struct KindRing: View {
    let slices: [KindSlice]

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                Circle()
                    .trim(from: seg.from, to: seg.to)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .padding(1.25)
            }
        }
    }

    private var segments: [(from: Double, to: Double, color: Color)] {
        var start = 0.0
        return slices.map { slice in
            defer { start += slice.share }
            return (start, start + slice.share, slice.color)
        }
    }
}

private struct DayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 알림 토스트

struct ToastInfo: Identifiable, Equatable {
    let id = UUID()
    let message: String
    /// 있으면 '실행 취소' 버튼이 나오고, 누르면 이 동작을 실행한다.
    var undo: (() -> Void)? = nil

    static func == (a: ToastInfo, b: ToastInfo) -> Bool { a.id == b.id }
}

private struct ToastView: View {
    let info: ToastInfo
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            Text(info.message)
                .lineLimit(2)
            Spacer()
            if info.undo != nil {
                Button(L("실행 취소"), action: onUndo)
                    .fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}
