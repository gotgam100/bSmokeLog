import SwiftUI
import SwiftData
import Charts

enum StatsRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .week: L("1주")
        case .month: L("1개월")
        case .quarter: L("3개월")
        }
    }
    var axisStride: Int {
        switch self {
        case .week: 1
        case .month: 7
        case .quarter: 30
        }
    }
}

struct StatsView: View {
    /// 지난 1년 + 비교용 직전 기간만 (종류도 한 번에 읽어 둔다)
    @Query(StatsView.descriptor) private var entries: [SmokeEntry]
    /// 같은 조건이면 계산 결과를 다시 쓴다 (화면이 다시 그려질 때마다 계산하지 않도록)
    @State private var memo = StatsMemo()
    @State private var saveToken = 0
    @Query(sort: \SmokeKind.order) private var kinds: [SmokeKind]
    /// 합계에서 뺀 날들
    @Query private var excludedDays: [ExcludedDay]
    @State private var range: StatsRange = .week
    /// nil = 전체, 아니면 그 종류만
    @State private var kindFilter: UUID?
    @AppStorage("firstWeekday") private var firstWeekday = 1

    var body: some View {
        NavigationStack {
            let (series, stats) = memo.value(
                key: "\(entries.count)-\(entries.last?.timestamp.timeIntervalSince1970 ?? 0)-\(range.rawValue)-\(kindFilter?.uuidString ?? "all")-\(kinds.map(\.colorKey))-\(saveToken)-\(AppLanguage.current.rawValue)-\(excludedDays.count)-\(excludedDays.reduce(0) { $0 + $1.day.timeIntervalSince1970 })"
            ) {
                let series = KindSeries(kinds: kinds, entries: entries)
                let filtered = kindFilter.map { id in entries.filter { $0.kind?.id == id } } ?? entries
                return (series, Stats(entries: filtered, days: range.rawValue, now: .now, series: series,
                                      excluded: ExcludedDay.days(excludedDays)))
            }
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle(title: L("통계")) {
                        SettingsButton()
                    }
                    Picker(L("기간"), selection: $range) {
                        ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if kinds.count > 1 {
                        kindChips
                    }

                    if stats.isEmpty {
                        ContentUnavailableView(
                            L("이 기간에는 기록이 없어요"),
                            systemImage: "chart.bar",
                            description: Text(L("달력에서 오늘 날짜를 누르면 기록이 쌓여요."))
                        )
                        .padding(.top, 40)
                    } else {
                        summary(stats)
                        if kindFilter == nil && stats.kindTotals.filter({ $0.count > 0 }).count > 1 {
                            kindBreakdown(stats)
                        }
                        dailyChart(stats, series)
                        hourlyChart(stats, series)
                        weekdayChart(stats, series)
                            .id(firstWeekday)
                    }
                }
                .padding(.horizontal)
                .padding(.top, ScreenTitle<EmptyView>.topPadding)
                .padding(.bottom, BottomTabBar.contentInset)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in saveToken += 1 }
        }
    }

    // MARK: - 종류 고르기

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(L("전체"), color: .primary, selected: kindFilter == nil) { kindFilter = nil }
                ForEach(kinds) { kind in
                    chip(kind.displayName, color: kind.color, selected: kindFilter == kind.id) { kindFilter = kind.id }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(_ title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if color != .primary {
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? (color == .primary ? Color.brand : color).opacity(0.18) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(Capsule().stroke(selected ? (color == .primary ? Color.brand : color) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 종류별 비율

    private func kindBreakdown(_ s: Stats) -> some View {
        ChartCard(title: L("종류별"), subtitle: L("최근 %@", range.title)) {
            VStack(spacing: 10) {
                ForEach(s.kindTotals.filter { $0.count > 0 }) { item in
                    let share = Double(item.count) / Double(max(s.total, 1))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.name).font(.subheadline)
                            Spacer()
                            Text(L("%d개 · %d%%", item.count, Int((share * 100).rounded())))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule().fill(item.color).frame(width: geo.size.width * share)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    // MARK: - 요약 카드

    private func summary(_ s: Stats) -> some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(title: L("하루 평균"), value: L("%.1f개비", s.average), caption: L("%d일 기준", s.trackedDays))
                StatCard(title: L("합계"), value: L("%d개비", s.total), caption: L("최근 %@", range.title))
                StatCard(title: L("평균 간격"), value: s.averageGap.map(durationText) ?? "-", caption: L("자는 시간 포함"))
                StatCard(title: L("자주 피는 시간"), value: s.peakHour.map(hourLabel) ?? "-", caption: L("가장 많이 기록된 시간대"))
            }
            if let text = comparisonText(s) {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func comparisonText(_ s: Stats) -> String? {
        guard let prev = s.previousAverage else { return nil }
        let diff = s.average - prev
        if abs(diff) < 0.1 { return L("직전 %@ 기간과 비슷해요.", range.title) }
        return diff < 0 ? L("직전 %@ 기간보다 하루 %.1f개비 적어요.", range.title, abs(diff)) : L("직전 %@ 기간보다 하루 %.1f개비 많아요.", range.title, abs(diff))
    }

    // MARK: - 차트

    private func dailyChart(_ s: Stats, _ series: KindSeries) -> some View {
        ChartCard(title: L("일별 기록"), subtitle: L("좌우로 넘겨 지난 기록 보기")) {
            // 평균 표시는 그래프 위에 따로 둬서 막대와 겹치지 않게
            HStack(spacing: 6) {
                Line()
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: 18, height: 1)
                Text(L("최근 %@ 평균 %.1f개비", range.title, s.average))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Chart {
                ForEach(s.historyByKind) { d in
                    BarMark(x: .value("날짜", d.date, unit: .day), y: .value("개비", d.count))
                        .foregroundStyle(by: .value("종류", d.kind))
                }
                RuleMark(y: .value("평균", s.average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.gray)
            }
            .chartForegroundStyleScale(domain: series.keys, range: series.colors)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range.axisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: range == .week)
                }
            }
            // 처음 기록한 날까지 좌우로 넘길 수 있고, 처음엔 최근 기간이 보인다
            .chartXScale(domain: s.historyStart...s.periodEnd)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: Double(range.rawValue) * 86_400)
            .chartScrollPosition(initialX: s.periodStart)
            .id(range)
            .frame(height: 180)
        }
    }

    private func hourlyChart(_ s: Stats, _ series: KindSeries) -> some View {
        ChartCard(title: L("시간대별"), subtitle: L("최근 %@ 합계", range.title)) {
            Chart(s.hourlyByKind) { h in
                BarMark(x: .value("시", String(h.hour)), y: .value("개비", h.count))
                    .foregroundStyle(by: .value("종류", h.kind))
            }
            .chartForegroundStyleScale(domain: series.keys, range: series.colors)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    if let s = value.as(String.self), let hour = Int(s), hour % 6 == 0 {
                        AxisValueLabel(L("%d시", hour))
                    }
                }
            }
            .frame(height: 150)
        }
    }

    private func weekdayChart(_ s: Stats, _ series: KindSeries) -> some View {
        ChartCard(title: L("요일별 평균")) {
            Chart(s.weekdayByKind) { w in
                BarMark(x: .value("요일", w.label), y: .value("평균", w.average))
                    .foregroundStyle(by: .value("종류", w.kind))
                    .annotation(position: .top) {
                        // 맨 위 칸에만 그 요일 합계 평균을 적는다
                        if w.isTop, w.total > 0 {
                            Text(String(format: "%.1f", w.total))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            .chartForegroundStyleScale(domain: series.keys, range: series.colors)
            .chartLegend(.hidden)
            .frame(height: 150)
        }
    }
}

/// 차트 계열 순서와 색. 설정의 종류 순서를 따르고, 종류 없는 기록이 있으면 '종류 없음'을 붙인다.
/// 이름이 같은 종류가 있어도 섞이지 않도록 id로 구분한다.
struct KindSeries {
    static let noneKey = "none"
    /// 차트에 쓰는 구분값 (종류 id)
    let keys: [String]
    let colors: [Color]
    private let labels: [String: String]

    init(kinds: [SmokeKind], entries: [SmokeEntry]) {
        var keys = kinds.map { $0.id.uuidString }
        var colors = kinds.map(\.color)
        var labels = Dictionary(kinds.map { ($0.id.uuidString, $0.displayName) }, uniquingKeysWith: { a, _ in a })
        if keys.isEmpty || entries.contains(where: { $0.kind == nil }) {
            keys.append(Self.noneKey)
            colors.append(Color.gray)
            labels[Self.noneKey] = L("종류 없음")
        }
        self.keys = keys
        self.colors = colors
        self.labels = labels
    }

    static func key(of entry: SmokeEntry) -> String {
        entry.kind?.id.uuidString ?? noneKey
    }

    func label(for key: String) -> String { labels[key] ?? "" }

    func color(for key: String) -> Color {
        keys.firstIndex(of: key).map { colors[$0] } ?? .brand
    }
}

// MARK: - 계산

/// 통계 계산 결과 기억 (참조형이라 화면을 그리는 중에 바꿔도 다시 그리기를 일으키지 않는다)
final class StatsMemo {
    private var key: String?
    private var cached: (KindSeries, Stats)?

    func value(key: String, compute: () -> (KindSeries, Stats)) -> (KindSeries, Stats) {
        if key == self.key, let cached { return cached }
        let v = compute()
        self.key = key
        cached = v
        return v
    }
}

extension StatsView {
    /// 통계는 가장 긴 기간(3개월) + 비교용 직전 3개월, 합쳐서 180일치만 있으면 된다
    static var descriptor: FetchDescriptor<SmokeEntry> {
        let since = Calendar.app.date(byAdding: .day, value: -180, to: Calendar.app.startOfDay(for: .now)) ?? .distantPast
        var d = FetchDescriptor<SmokeEntry>(predicate: #Predicate { $0.timestamp >= since },
                                            sortBy: [SortDescriptor(\.timestamp)])
        d.relationshipKeyPathsForPrefetching = [\.kind]
        return d
    }
}

struct Stats {
    struct DayKind: Identifiable { let date: Date; let kind: String; let count: Int; var id: String { "\(date.timeIntervalSince1970)-\(kind)" } }
    struct HourKind: Identifiable { let hour: Int; let kind: String; let count: Int; var id: String { "\(hour)-\(kind)" } }
    struct WeekdayKind: Identifiable {
        let index: Int; let label: String; let kind: String; let average: Double
        let isTop: Bool; let total: Double
        var id: String { "\(index)-\(kind)" }
    }
    struct KindTotal: Identifiable { let key: String; let name: String; let color: Color; let count: Int; var id: String { key } }

    let isEmpty: Bool
    let total: Int
    /// 기록을 시작한 날 이후만 평균에 포함 (앱 설치 전 날짜가 0으로 끌어내리지 않도록)
    let trackedDays: Int
    let average: Double
    let previousAverage: Double?
    let peakHour: Int?
    let averageGap: TimeInterval?
    /// 최근 90일 중 기록이 있는 날 (일별 차트를 좌우로 넘겨 볼 때)
    let historyByKind: [DayKind]
    let historyStart: Date
    let periodStart: Date
    let periodEnd: Date
    let hourlyByKind: [HourKind]
    let weekdayByKind: [WeekdayKind]
    let kindTotals: [KindTotal]

    /// - excluded: 합계에서 뺀 날들(0시). 그 날의 기록은 세지 않고, 평균을 낼 때 날수에서도 뺀다.
    init(entries: [SmokeEntry], days: Int, now: Date, series: KindSeries, excluded: Set<Date> = []) {
        let cal = Calendar.app
        let today = cal.startOfDay(for: now)
        let start = cal.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let end = cal.date(byAdding: .day, value: 1, to: today) ?? now
        let entries = excluded.isEmpty ? entries : entries.filter { !excluded.contains(cal.startOfDay(for: $0.timestamp)) }

        let times = entries.map(\.timestamp).sorted()
        let inRange = times.filter { $0 >= start && $0 < end }
        let firstDay = times.first.map { cal.startOfDay(for: $0) }

        isEmpty = inRange.isEmpty
        total = inRange.count

        // 기간 안의 날짜 목록 (평균의 분모). 합계에서 뺀 날은 빠진다.
        let periodDays = (0..<days).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
            .filter { !excluded.contains($0) }

        let effectiveStart = max(start, firstDay ?? today)
        trackedDays = periodDays.filter { $0 >= effectiveStart }.count
        average = Double(total) / Double(max(trackedDays, 1))

        if let firstDay, firstDay < start,
           let prevStart = cal.date(byAdding: .day, value: -days, to: start) {
            let from = max(prevStart, firstDay)
            let prevDays = (cal.dateComponents([.day], from: from, to: start).day ?? 0)
                - excluded.filter { $0 >= from && $0 < start }.count
            let prevCount = times.filter { $0 >= from && $0 < start }.count
            previousAverage = prevDays > 0 ? Double(prevCount) / Double(prevDays) : nil
        } else {
            previousAverage = nil
        }

        var hours = Array(repeating: 0, count: 24)
        for t in inRange { hours[cal.component(.hour, from: t)] += 1 }
        peakHour = total > 0 ? hours.indices.max { hours[$0] < hours[$1] } : nil

        // 요일마다 기간 안에 며칠 있었는지 (기록 시작 전 날짜는 빼고)
        var ns = Array(repeating: 0, count: 8)
        for day in periodDays where day >= effectiveStart {
            ns[cal.component(.weekday, from: day)] += 1
        }
        let symbols = cal.shortStandaloneWeekdaySymbols

        // 자는 시간도 '안 피운 시간'이라 그대로 넣는다.
        // 합계에서 뺀 날을 사이에 둔 간격만 뺀다(그날은 기록이 없어 간격을 알 수 없다).
        let gaps = zip(inRange, inRange.dropFirst())
            .filter { pair in !excluded.contains { $0 > pair.0 && $0 < pair.1 } }
            .map { $1.timeIntervalSince($0) }
        averageGap = gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)

        // 종류별로 나눈 값 (차트를 종류 색으로 쌓는 데 쓴다)
        let rangeEntries = entries.filter { $0.timestamp >= start && $0.timestamp < end }
        func name(_ e: SmokeEntry) -> String { KindSeries.key(of: e) }
        let present = series.keys.filter { n in rangeEntries.contains { name($0) == n } }

        var dayKind: [Date: [String: Int]] = [:]
        var hourKind = Array(repeating: [String: Int](), count: 24)
        var kindCount: [String: Int] = [:]
        for e in rangeEntries {
            dayKind[cal.startOfDay(for: e.timestamp), default: [:]][name(e), default: 0] += 1
            hourKind[cal.component(.hour, from: e.timestamp)][name(e), default: 0] += 1
            kindCount[name(e), default: 0] += 1
        }
        // 전체 기간: 기록이 있는 날만 담는다(빈 날은 막대가 없으면 그만)
        var historyCount: [Date: [String: Int]] = [:]
        let historyFloor = cal.date(byAdding: .day, value: -89, to: today) ?? today
        for e in entries where e.timestamp < end && e.timestamp >= historyFloor {
            historyCount[cal.startOfDay(for: e.timestamp), default: [:]][name(e), default: 0] += 1
        }
        historyByKind = historyCount.keys.sorted().flatMap { day in
            series.keys.compactMap { k in historyCount[day]?[k].map { DayKind(date: day, kind: k, count: $0) } }
        }
        historyStart = max(historyFloor, min(start, firstDay ?? start))
        periodStart = start
        periodEnd = end

        hourlyByKind = (0..<24).flatMap { h in
            present.map { HourKind(hour: h, kind: $0, count: hourKind[h][$0] ?? 0) }
        }
        kindTotals = series.keys.map { KindTotal(key: $0, name: series.label(for: $0), color: series.color(for: $0), count: kindCount[$0] ?? 0) }

        // 요일별 종류 합계 (기록은 모두 effectiveStart 이후이므로 그대로 더한다)
        var wkSums = Array(repeating: [String: Int](), count: 8)
        for e in rangeEntries {
            wkSums[cal.component(.weekday, from: e.timestamp)][name(e), default: 0] += 1
        }
        weekdayByKind = (0..<7).flatMap { i -> [WeekdayKind] in
            let w = (cal.firstWeekday - 1 + i) % 7 + 1
            let n = Double(max(ns[w], 1))
            let total = ns[w] > 0 ? Double(wkSums[w].values.reduce(0, +)) / n : 0
            return present.enumerated().map { j, k in
                WeekdayKind(index: i, label: symbols[w - 1], kind: k,
                            average: ns[w] > 0 ? Double(wkSums[w][k] ?? 0) / n : 0,
                            isTop: j == present.count - 1, total: total)
            }
        }
    }
}

// MARK: - 카드 컴포넌트

private struct StatCard: View {
    let title: String
    let value: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 범례용 가로 점선
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
