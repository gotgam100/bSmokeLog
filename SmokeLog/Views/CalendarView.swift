import SwiftUI
import SwiftData

/// 복사해 둔 하루 기록. 날짜와 무관하게 "그 날 0시부터 몇 초 뒤"로 저장해서 다른 날에 붙여넣는다.
struct DayClipboard {
    let sourceDay: Date
    let items: [Item]

    struct Item {
        let offset: TimeInterval
        let memo: String
        /// 종류 자체가 아니라 id만 들고 있다가, 붙여넣을 때 다시 찾는다(그 사이 종류가 지워졌을 수 있음).
        let kindID: UUID?
    }

    /// 하루치 기록을 그 날 0시 기준으로 담는다.
    static func make(from entries: [SmokeEntry], dayStart: Date) -> DayClipboard {
        DayClipboard(
            sourceDay: dayStart,
            items: entries.map { Item(offset: $0.timestamp.timeIntervalSince(dayStart), memo: $0.memo, kindID: $0.kind?.id) }
        )
    }
}

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
    @State private var clipboard: DayClipboard?
    @State private var pasteTarget: Date?

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
                                clipboard: clipboard,
                                onTap: { day in
                                    if day <= now { openDay(day) }
                                },
                                onAdd: add(to:),
                                onRemove: removeLatest(on:),
                                onCopy: copy,
                                onPaste: requestPaste(to:)
                            )
                            .id(firstWeekday)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                        Text(L("날짜를 누르면 그날 기록 보기 · 꾹 누르면 추가, 삭제, 복사, 붙여넣기"))
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
            .confirmationDialog(
                L("이 날에 이미 기록이 있어요"),
                isPresented: Binding(get: { pasteTarget != nil }, set: { if !$0 { pasteTarget = nil } }),
                titleVisibility: .visible,
                presenting: pasteTarget
            ) { day in
                Button(L("기존 기록을 지우고 붙여넣기"), role: .destructive) { paste(to: day, replace: true) }
                Button(L("기존 기록에 더하기")) { paste(to: day, replace: false) }
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

    private func copy(_ day: Date) {
        let start = cal.startOfDay(for: day)
        let dayEntries = entries(on: day)
        guard !dayEntries.isEmpty else { return }
        clipboard = .make(from: dayEntries, dayStart: start)
        showToast(ToastInfo(message: L("%@ 기록 %d개를 복사했어요", shortDate(start), dayEntries.count)))
    }

    private func requestPaste(to day: Date) {
        guard clipboard != nil else { return }
        if entries(on: day).isEmpty {
            paste(to: day, replace: false)
        } else {
            pasteTarget = day
        }
    }

    private func paste(to day: Date, replace: Bool) {
        guard let clipboard else { return }
        let start = cal.startOfDay(for: day)
        let now = Date.now
        withAnimation(.snappy) {
            if replace {
                for e in entries(on: day) { context.delete(e) }
            }
        }
        var inserted: [SmokeEntry] = []
        for item in clipboard.items {
            let time = start.addingTimeInterval(item.offset)
            guard time <= now else { continue } // 아직 오지 않은 시각은 건너뜀
            let entry = SmokeEntry(timestamp: time, memo: item.memo, kind: KindStore.kind(id: item.kindID, in: context))
            context.insert(entry)
            inserted.append(entry)
        }
        let skipped = clipboard.items.count - inserted.count
        var message = L("%@에 %d개를 붙여넣었어요", shortDate(start), inserted.count)
        if skipped > 0 { message += L(" (미래 시각 %d개 제외)", skipped) }
        let ids = inserted.map(\.persistentModelID)
        let undo: (() -> Void)? = replace ? nil : { [context] in
            withAnimation(.snappy) { KindStore.deleteEntries(ids, in: context) }
        }
        showToast(ToastInfo(message: message, undo: undo))
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

/// 보이는 달의 하루 평균·합계와 지난달 평균. 이번 달이면 누르면 오늘 화면으로 간다.
private struct MonthSummary: View {
    let month: Date
    let now: Date
    let onTap: () -> Void
    /// 지난달 1일부터 이달 말까지
    @Query private var entries: [SmokeEntry]

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
        let thisCount = entries.filter { $0.timestamp >= month }.count
        let prevCount = entries.count - thisCount
        // 이번 달은 오늘까지 지난 날수로, 지난 달은 그 달 날수로 나눈다
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let days = isCurrent ? cal.component(.day, from: now) : daysInMonth
        let prevMonth = cal.date(byAdding: .month, value: -1, to: month) ?? month
        let prevDays = cal.range(of: .day, in: .month, for: prevMonth)?.count ?? 30
        let average = Double(thisCount) / Double(max(days, 1))
        let prevAverage = Double(prevCount) / Double(max(prevDays, 1))

        let card = HStack(alignment: .bottom, spacing: 12) {
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

// MARK: - 달력 그리드

private struct MonthGrid: View {
    let month: Date
    let now: Date
    let dailyLimit: Int
    let clipboard: DayClipboard?
    let onTap: (Date) -> Void
    let onAdd: (Date) -> Void
    let onRemove: (Date) -> Void
    let onCopy: (Date) -> Void
    let onPaste: (Date) -> Void

    /// 보이는 달의 기록만 읽는다 (몇 년치가 쌓여도 한 달치만)
    @Query private var monthEntries: [SmokeEntry]

    private let cal = Calendar.app
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(month: Date, now: Date, dailyLimit: Int, clipboard: DayClipboard?,
         onTap: @escaping (Date) -> Void, onAdd: @escaping (Date) -> Void, onRemove: @escaping (Date) -> Void,
         onCopy: @escaping (Date) -> Void, onPaste: @escaping (Date) -> Void) {
        self.month = month
        self.now = now
        self.dailyLimit = dailyLimit
        self.clipboard = clipboard
        self.onTap = onTap
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onCopy = onCopy
        self.onPaste = onPaste
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
                    Button { onTap(day) } label: {
                        DayCell(
                            day: cal.component(.day, from: day),
                            count: count,
                            isToday: isToday,
                            isFuture: isFuture,
                            isSunday: cal.component(.weekday, from: day) == 1,
                            intensity: Double(count) / Double(maxCount),
                            slices: slices[day] ?? [],
                            overLimit: dailyLimit > 0 && count > dailyLimit
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
                            Button { onCopy(day) } label: {
                                Label(L("복사"), systemImage: "doc.on.doc")
                            }
                            .disabled(count == 0)
                            if let clipboard {
                                Button { onPaste(day) } label: {
                                    Label(L("붙여넣기"), systemImage: "doc.on.clipboard")
                                    Text(L("%@ 기록", clipboard.sourceDay.formatted(Date.FormatStyle(locale: .app).month().day())))
                                }
                            }
                        }
                    }
                    .accessibilityLabel(Text(day, format: .dateTime.month().day()))
                    .accessibilityValue(L("%d개비", count))
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

    private var dateColor: Color {
        if isSunday { return .red }
        return isToday ? .brand : .primary
    }

    /// 개비 수는 요일과 상관없이 같은 색 (일요일 빨강은 날짜에만)
    private var countColor: Color {
        if overLimit { return Color(red: 0.85, green: 0.1, blue: 0.15) }
        return count > 0 ? .primary : .brand
    }

    private var badgeFill: Color {
        if isFuture { return .clear }
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
                if count > 0 {
                    KindRing(slices: slices)
                } else if isToday {
                    Circle().strokeBorder(Color.brand, lineWidth: 2)
                }
                Text(count > 0 ? "\(count)" : "")
                    .font(.subheadline.weight(overLimit ? .heavy : .semibold).monospacedDigit())
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
