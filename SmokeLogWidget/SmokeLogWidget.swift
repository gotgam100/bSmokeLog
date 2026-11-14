import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

@main
struct SmokeLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        AddSmokeControl()
    }
}

// MARK: - 데이터

struct TodayEntry: TimelineEntry {
    let date: Date
    let count: Int
    let last: Date?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, count: 3, last: .now.addingTimeInterval(-1800))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.load(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        // '마지막 ○분 전'이 너무 낡지 않도록 15분마다, 그리고 자정에 새로 그린다.
        var dates = (0..<8).map { now.addingTimeInterval(Double($0) * 900) }
        if let midnight = Calendar.app.date(byAdding: .day, value: 1, to: Calendar.app.startOfDay(for: now)) {
            dates = dates.filter { $0 < midnight } + [midnight]
        }
        let base = Self.load(at: now)
        let entries = dates.map { date in
            // 자정이 지나면 오늘 개수는 0부터
            Calendar.app.isDate(date, inSameDayAs: now) ? TodayEntry(date: date, count: base.count, last: base.last)
                                                       : TodayEntry(date: date, count: 0, last: base.last)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// 위젯은 뒤쪽 스레드에서 불리므로, 메인 스레드를 거치지 않고 그 자리에서 읽는다
    private static func load(at date: Date) -> TodayEntry {
        guard let container = try? AppStore.makeExtensionContainer() else {
            return TodayEntry(date: date, count: 0, last: nil)
        }
        let context = ModelContext(container)
        let start = Calendar.app.startOfDay(for: date)
        let count = (try? context.fetchCount(FetchDescriptor<SmokeEntry>(
            predicate: #Predicate { $0.timestamp >= start }
        ))) ?? 0
        var latest = FetchDescriptor<SmokeEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        latest.fetchLimit = 1
        let last = (try? context.fetch(latest))?.first?.timestamp
        return TodayEntry(date: date, count: count, last: last)
    }
}

// MARK: - 위젯

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .environment(\.locale, .app)
        }
        .configurationDisplayName(L("오늘"))
        .description(L("오늘 개수를 보고, 누르면 바로 한 개비를 기록해요."))
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: AddSmokeIntent()) {
                VStack(spacing: 0) {
                    Text("\(entry.count)")
                        .font(.title2.bold())
                        .monospacedDigit()
                    Image(systemName: "plus")
                        .font(.caption2.bold())
                }
            }
            .buttonStyle(.plain)
            .widgetAccentable()
        case .accessoryRectangular:
            Button(intent: AddSmokeIntent()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("오늘 %d개비", entry.count))
                        .font(.headline)
                    lastText
                        .font(.caption)
                    Text(L("눌러서 +1"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        case .accessoryInline:
            Text(L("오늘 %d개비", entry.count))
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("오늘"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(entry.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(L("개비"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            lastText
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(intent: AddSmokeIntent()) {
                Label(L("한 개비"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .tint(.brand)
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var lastText: some View {
        if let last = entry.last {
            Text(L("마지막 %@", elapsedText(from: last, to: entry.date)))
        } else {
            Text(L("아직 기록이 없어요"))
        }
    }
}

// MARK: - 제어 센터·잠금 화면·액션 버튼

struct AddSmokeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.seunghwabaek.bsmokelog.add") {
            ControlWidgetButton(action: AddSmokeIntent()) {
                Label(L("한 개비 기록"), systemImage: "plus.circle")
            }
        }
        .displayName(LocalizedStringResource(stringLiteral: L("한 개비 기록")))
        .description(LocalizedStringResource(stringLiteral: L("지금 시각으로 한 개비를 기록해요.")))
    }
}
