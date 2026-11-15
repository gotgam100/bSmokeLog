import SwiftUI
import SwiftData

/// 아래 메뉴 '오늘' 화면. 원형 시간표에서 점을 끌어 시각을 옮기고, 목록에서 시간 수정·선택 삭제·직접 추가를 할 수 있다.
struct DayDetailView: View {
    let day: Date
    /// 제목 아래 화살표로 하루 앞뒤로 넘길 때 (-1 / +1)
    var onShiftDay: ((Int) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Query private var entries: [SmokeEntry]
    /// 가장 최근 기록 하나 (원형표 가운데 '마지막 N분 전'용)
    @Query private var latestEntries: [SmokeEntry]
    @State private var newTime: Date
    @State private var newMemo = ""
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var editing: SmokeEntry?
    @State private var confirmDelete = false
    @State private var showHelp = false

    private let start: Date
    private let end: Date

    init(day: Date, onShiftDay: ((Int) -> Void)? = nil) {
        self.onShiftDay = onShiftDay
        let cal = Calendar.app
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        self.day = start
        self.start = start
        self.end = end
        _entries = Query(
            filter: #Predicate<SmokeEntry> { $0.timestamp >= start && $0.timestamp < end },
            sort: \SmokeEntry.timestamp,
            order: .reverse
        )
        var latest = FetchDescriptor<SmokeEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        latest.fetchLimit = 1
        _latestEntries = Query(latest)
        let isToday = cal.isDateInToday(start)
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
        _newTime = State(initialValue: isToday ? .now : noon)
    }

    /// 고를 수 있는 가장 늦은 시각: 그 날의 마지막 순간, 오늘이면 지금
    private var latestAllowed: Date {
        max(start, min(end.addingTimeInterval(-1), .now))
    }

    private var isEditing: Bool { editMode.isEditing }

    /// 오늘을 볼 때만: 가장 최근에 피운 시각 (오늘 기록이 없으면 어제 이전 것)
    private var lastSmoke: Date? {
        Calendar.app.isDateInToday(start) ? latestEntries.first?.timestamp : nil
    }

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                Section {
                    DayClockView(entries: entries, dayStart: start, latest: latestAllowed, lastSmoke: lastSmoke) { entry, date in
                        entry.timestamp = date
                    } onAdd: { date in
                        withAnimation { context.insert(SmokeEntry(timestamp: date, kind: KindStore.defaultKind(context))) }
                    } onDelete: { entry in
                        withAnimation { context.delete(entry) }
                    }
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    // 원형표는 카드 없이 배경 위에 바로 놓는다
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    screenHeader
                }

                // 첫 담배 · 마지막 시간
                Section {
                    firstLastCard
                }

                Section {
                    if entries.isEmpty {
                        Text(L("기록이 없어요"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                        Button {
                            editing = entry
                        } label: {
                            HStack {
                                Circle()
                                    .fill(entry.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text(entry.timestamp, format: .dateTime.hour().minute())
                                            .monospacedDigit()
                                            .foregroundStyle(.primary)
                                        if let kind = entry.kind {
                                            Text(kind.displayName)
                                                .font(.caption)
                                                .foregroundStyle(kind.color)
                                        }
                                    }
                                    if !entry.memo.isEmpty {
                                        Text(entry.memo)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer()
                                if index + 1 < entries.count {
                                    let gap = entry.timestamp.timeIntervalSince(entries[index + 1].timestamp)
                                    Text("+\(durationText(gap))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                if !isEditing {
                                    Image(systemName: "pencil")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .tint(.primary)
                        .tag(entry.persistentModelID)
                        .deleteDisabled(isEditing)
                    }
                    .onDelete(perform: delete)
                } header: {
                    HStack(spacing: 16) {
                        Text(L("기록"))
                        Spacer()
                        // 아래 메뉴가 화면 아래를 가려서, 선택 도구를 여기에 둔다
                        if isEditing {
                            Button(selection.count == entries.count ? L("선택 해제") : L("전체 선택")) {
                                if selection.count == entries.count {
                                    selection.removeAll()
                                } else {
                                    selection = Set(entries.map(\.persistentModelID))
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .textCase(nil)
                            Button(L("%d개 삭제", selection.count), role: .destructive) {
                                confirmDelete = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .tint(.red)
                            .disabled(selection.isEmpty)
                            .textCase(nil)
                        }
                        if !entries.isEmpty {
                            Button(isEditing ? L("취소") : L("선택")) {
                                withAnimation {
                                    editMode = isEditing ? .inactive : .active
                                    selection.removeAll()
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .textCase(nil)
                        }
                    }
                }

                Section {
                    DatePicker(L("시간"), selection: $newTime, in: start...latestAllowed, displayedComponents: .hourAndMinute)
                    TextField(L("메모 (선택)"), text: $newMemo, axis: .vertical)
                        .lineLimit(1...3)
                    Button {
                        let memo = newMemo.trimmingCharacters(in: .whitespacesAndNewlines)
                        withAnimation { context.insert(SmokeEntry(timestamp: newTime, memo: memo, kind: KindStore.defaultKind(context))) }
                        newMemo = ""
                    } label: {
                        Label(L("이 시간으로 추가"), systemImage: "plus.circle")
                    }
                } header: {
                    Text(L("직접 추가"))
                }
            }
            .environment(\.editMode, $editMode)
            // 다른 화면처럼 제목·설정을 맨 위에 직접 그린다
            .toolbar(.hidden, for: .navigationBar)
            .contentMargins(.top, ScreenTitle<EmptyView>.topPadding - 10, for: .scrollContent)
            .contentMargins(.bottom, BottomTabBar.contentInset, for: .scrollContent)
            .confirmationDialog(L("선택한 기록 %d개를 삭제할까요?", selection.count), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L("삭제"), role: .destructive, action: deleteSelected)
            }
            .sheet(item: $editing) { entry in
                EditEntrySheet(entry: entry, range: start...latestAllowed)
            }
        }
    }

    /// 그날 첫 담배와 마지막 담배 시각. 오늘이면 마지막 아래에 '몇 분 전'도 함께.
    private var firstLastCard: some View {
        // entries는 최신순이라 마지막이 첫 담배
        let first = entries.last?.timestamp
        let last = entries.first?.timestamp
        let timeStyle = Date.FormatStyle(locale: .app).hour().minute()
        return HStack(spacing: 0) {
            timeColumn(title: L("첫 담배"), time: first.map { $0.formatted(timeStyle) })
            Divider().frame(height: 36)
            timeColumn(title: L("마지막 담배"), time: last.map { $0.formatted(timeStyle) })
        }
        .padding(.vertical, 4)
    }

    private func timeColumn(title: String, time: String?) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(time ?? "–")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(time == nil ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// 화면 맨 위: 제목 + 설정, 그 아래 < 날짜 >
    private var screenHeader: some View {
        VStack(spacing: 14) {
            ScreenTitle(title: L("오늘")) {
                SettingsButton()
            }
            .padding(.horizontal, -16)
            HStack(spacing: 4) {
                Button { onShiftDay?(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L("전날"))
                Text(day, format: .dateTime.month().day().weekday(.wide))
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .monospacedDigit()
                    .lineLimit(1)
                Button { onShiftDay?(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(Calendar.app.isDateInToday(day) || day > .now)
                .accessibilityLabel(L("다음날"))
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            // 원형표 오른쪽 위 작은 i: 누르면 사용 방법 팝업
            .overlay(alignment: .trailing) { helpButton }
        }
        .textCase(nil)
        .padding(.bottom, 6)
    }

    private var helpButton: some View {
        Button {
            showHelp = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("사용 방법"))
        .popover(isPresented: $showHelp, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("원형 시간표를 꾹 눌러서 손쉽게 추가/삭제가 가능해요."), systemImage: "hand.tap")
                Label(L("점을 클릭해 끌면 시간 변경이 가능해요."), systemImage: "hand.draw")
            }
            .font(.subheadline)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(maxWidth: 300, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { entries[$0] }
        withAnimation {
            for entry in targets { context.delete(entry) }
        }
    }

    private func deleteSelected() {
        let targets = entries.filter { selection.contains($0.persistentModelID) }
        withAnimation {
            for entry in targets { context.delete(entry) }
            selection.removeAll()
            editMode = .inactive
        }
    }
}

/// 기록 하나의 시간과 메모를 고친다.
private struct EditEntrySheet: View {
    let entry: SmokeEntry
    let range: ClosedRange<Date>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    @State private var memo: String
    @State private var kind: SmokeKind?
    @Query(sort: \SmokeKind.order) private var kinds: [SmokeKind]
    @FocusState private var memoFocused: Bool

    init(entry: SmokeEntry, range: ClosedRange<Date>) {
        self.entry = entry
        self.range = range
        _time = State(initialValue: entry.timestamp)
        _memo = State(initialValue: entry.memo)
        _kind = State(initialValue: entry.kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("시간")) {
                    DatePicker(L("시간"), selection: $time, in: range, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                Section(L("메모")) {
                    TextField(L("예: 커피 마시고, 회의 끝나고"), text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($memoFocused)
                }
                Section {
                    ForEach(kinds) { option in
                        Button {
                            kind = option
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(option.color).frame(width: 14, height: 14)
                                Text(option.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if kind?.id == option.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(option.color)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                    if kinds.isEmpty {
                        Text(L("설정에서 종류를 추가할 수 있어요"))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L("종류"))
                }
                Section {
                    Button(L("이 기록 삭제"), role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L("기록 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("취소")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("저장")) {
                        entry.timestamp = time
                        entry.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
                        entry.kind = kind
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
