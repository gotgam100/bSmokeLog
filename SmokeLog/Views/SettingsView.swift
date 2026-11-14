import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    /// 설정 창 닫기
    var onClose: () -> Void = {}
    @Environment(\.modelContext) private var context
    /// 기록 개수만 센다 (전체 기록을 들고 있지 않음)
    @State private var entryCount = 0
    @Query(sort: \SmokeKind.order) private var kinds: [SmokeKind]
    @AppStorage(KindStore.defaultKey, store: AppStore.defaults) private var defaultKindID = ""
    @AppStorage(AppStore.Key.dailyLimit, store: AppStore.defaults) private var dailyLimit = 0
    @AppStorage(AppStore.Key.weeklySummary, store: AppStore.defaults) private var weeklySummary = false
    @AppStorage(AppStore.Key.iCloudSync, store: AppStore.defaults) private var iCloudSync = true
    @State private var notificationDenied = false
    @State private var addingKind = false
    /// 기본 종류가 아닌 것들을 펼쳐 볼지
    @State private var showOtherKinds = false
    @AppStorage(AppLanguage.key, store: AppStore.defaults) private var language = AppLanguage.current.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("firstWeekday") private var firstWeekday = 1
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("언어"), selection: $language) {
                        Text(L("한국어")).tag(AppLanguage.ko.rawValue)
                        Text(L("영어")).tag(AppLanguage.en.rawValue)
                    }
                    Toggle(L("기록할 때 진동"), isOn: $hapticsEnabled)
                    Toggle(isOn: $weeklySummary) {
                        Text(L("주간 한 줄 요약"))
                        Text(L("매주 일요일 저녁 8시에 알려줘요"))
                            .font(.footnote)
                    }
                        .onChange(of: weeklySummary) { _, on in
                            Task { @MainActor in
                                if on, !(await WeeklySummary.requestPermission()) {
                                    weeklySummary = false
                                    notificationDenied = true
                                }
                                WeeklySummary.reschedule(context: context)
                            }
                        }
                    Picker(L("한 주의 시작"), selection: $firstWeekday) {
                        Text(L("일요일")).tag(1)
                        Text(L("월요일")).tag(2)
                    }
                    // 0이면 꺼짐. 넘은 날은 달력 숫자 색만 바뀐다.
                    HStack {
                        Text(L("하루 기준선"))
                        Spacer()
                        HStack(spacing: 14) {
                            Button {
                                dailyLimit = max(0, dailyLimit - 1)
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .disabled(dailyLimit == 0)
                            Text(L("%d개비", dailyLimit))
                                .monospacedDigit()
                                .frame(minWidth: 52)
                            Button {
                                dailyLimit = min(60, dailyLimit + 1)
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .disabled(dailyLimit == 60)
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    // 화면 제목을 첫 묶음 머리글에 함께 둬서 달력·통계와 같은 자리에 오게 한다
                    VStack(alignment: .leading, spacing: 18) {
                        ScreenTitle(title: L("B흡연로그")) {
                            Button(L("완료"), action: onClose)
                                .font(.body.weight(.semibold))
                                .textCase(nil)
                        }
                        .padding(.leading, -16)
                        .padding(.trailing, -16)
                        Text(L("설정"))
                    }
                }

                Section {
                    // 기본 종류는 늘 보이고, 나머지는 색 점만 보이는 한 줄로 접어 둔다
                    ForEach(kinds.filter(isDefault)) { kind in
                        kindRow(kind)
                    }
                    let others = kinds.filter { !isDefault($0) }
                    if !others.isEmpty {
                        Button {
                            withAnimation(.snappy) { showOtherKinds.toggle() }
                        } label: {
                            HStack(spacing: 12) {
                                // 색 점을 겹쳐 쌓되 다른 줄의 점과 같은 폭(14)을 차지하게 해서 글자 줄을 맞춘다
                                ZStack {
                                    ForEach(Array(others.prefix(3).enumerated().reversed()), id: \.offset) { i, kind in
                                        Circle()
                                            .fill(kind.color)
                                            .frame(width: 14, height: 14)
                                            .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                                            .offset(x: CGFloat(-7 * i))
                                    }
                                }
                                .frame(width: 14, height: 14)
                                Text(L("다른 종류 %d개", others.count))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(showOtherKinds ? 180 : 0))
                            }
                        }
                        .tint(.primary)
                        if showOtherKinds {
                            ForEach(others) { kind in
                                kindRow(kind)
                            }
                            .onDelete { offsets in
                                for kind in offsets.map({ others[$0] }) { context.delete(kind) }
                            }
                        }
                    }

                    Button {
                        addingKind = true
                    } label: {
                        Label(L("종류 추가"), systemImage: "plus.circle")
                    }

                    if !kinds.isEmpty {
                        Picker(L("새 기록의 기본 종류"), selection: $defaultKindID) {
                            ForEach(kinds) { kind in
                                Text(kind.displayName).tag(kind.id.uuidString)
                            }
                        }
                    }
                } header: {
                    Text(L("담배 종류"))
                }

                Section {
                    Toggle(isOn: $iCloudSync) {
                        Text(L("iCloud 동기화"))
                        Text(L("앱을 다시 실행하면 적용돼요"))
                            .font(.footnote)
                    }

                    ShareLink(
                        item: CSVExport(container: context.container),
                        preview: SharePreview(L("B흡연로그") + ".csv", image: Image(systemName: "tablecells"))
                    ) {
                        Label {
                            Text(L("CSV 파일로 내보내기"))
                            Text(L("엑셀에서 열 수 있는 목록 파일로 저장해요"))
                                .font(.footnote)
                                .foregroundStyle(Color(.secondaryLabel))
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(entryCount == 0)

                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label(L("모든 기록 삭제"), systemImage: "trash")
                    }
                    .tint(.red)
                    .disabled(entryCount == 0)
                } header: {
                    Text(L("데이터"))
                }

                Section(L("정보")) {
                    LabeledContent(L("버전"), value: appVersion)
                    Link(destination: Self.policyURL) {
                        HStack {
                            Text(L("이용약관 및 정책"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: Self.otherAppsURL) {
                        HStack {
                            Text(L("개발자의 다른 앱"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .contentMargins(.top, ScreenTitle<EmptyView>.topPadding - 10, for: .scrollContent)
            .navigationDestination(isPresented: $addingKind) {
                NewKindView(nextOrder: (kinds.map(\.order).max() ?? -1) + 1,
                            usedColors: Set(kinds.map(\.colorKey)))
            }
            .onAppear {
                fixDefaultKind()
                refreshCount()
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in refreshCount() }
            .onChange(of: kinds.map(\.id)) { fixDefaultKind() }
            .alert(L("알림이 꺼져 있어요"), isPresented: $notificationDenied) {
                Button(L("확인"), role: .cancel) {}
            } message: {
                Text(L("아이폰 설정 > 알림에서 B흡연로그를 허용해 주세요."))
            }
            .alert(L("모든 기록을 삭제할까요?"), isPresented: $confirmDeleteAll) {
                Button(L("취소"), role: .cancel) {}
                Button(L("모두 삭제"), role: .destructive) {
                    try? context.delete(model: SmokeEntry.self)
                    try? context.save()
                    refreshCount()
                }
            } message: {
                Text(L("기록 %d개가 지워지고 되돌릴 수 없어요.", entryCount))
            }
        }
    }

    private func refreshCount() {
        entryCount = (try? context.fetchCount(FetchDescriptor<SmokeEntry>())) ?? 0
    }

    private func isDefault(_ kind: SmokeKind) -> Bool {
        kind.id.uuidString == defaultKindID
    }

    /// 기본 종류가 비었거나 지워졌으면 맨 위 종류로 맞춘다.
    private func fixDefaultKind() {
        if !kinds.contains(where: { $0.id.uuidString == defaultKindID }), let first = kinds.first {
            defaultKindID = first.id.uuidString
        }
    }

    /// 개인정보 처리방침·이용약관·고객지원 페이지 (GitHub Pages)
    private static let policyURL = URL(string: "https://gotgam100.github.io/bSmokeLog/")!

    /// 앱스토어에서 개발자 이름으로 검색한 화면
    private static let otherAppsURL = URL(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=Seunghwa%20Baek")!

    private func kindRow(_ kind: SmokeKind) -> some View {
        NavigationLink {
            KindEditView(kind: kind)
        } label: {
            HStack(spacing: 12) {
                Circle().fill(kind.color).frame(width: 14, height: 14)
                Text(kind.name.isEmpty ? L("이름 없음") : kind.displayName)
                Spacer()
                if isDefault(kind) {
                    Text(L("기본"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

/// 엑셀에서 한글이 깨지지 않도록 BOM을 붙인 CSV.
/// 공유를 누른 순간에만, 화면과 별도로(백그라운드에서) 기록을 읽어 만든다.
struct CSVExport: Transferable {
    let container: ModelContainer

    static func makeCSV(container: ModelContainer, header: String) -> String {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SmokeEntry>(sortBy: [SortDescriptor(\.timestamp)])
        descriptor.relationshipKeyPathsForPrefetching = [\.kind]
        let entries = (try? context.fetch(descriptor)) ?? []
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd,HH:mm"
        // 메모 안의 쉼표·줄바꿈·따옴표가 칸을 깨뜨리지 않도록 따옴표로 감싼다.
        func quoted(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var out = "\u{FEFF}" + header + "\n"
        for e in entries {
            out += formatter.string(from: e.timestamp) + "," + quoted(e.kind?.displayName ?? "") + "," + quoted(e.memo) + "\n"
        }
        return out
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { item in
            let header = L("날짜,시각,종류,메모")
            let container = item.container
            return await Task.detached(priority: .userInitiated) {
                Data(makeCSV(container: container, header: header).utf8)
            }.value
        }
        .suggestedFileName(L("B흡연로그") + ".csv")
    }
}

/// 종류 하나의 이름과 색을 고친다.
private struct KindEditView: View {
    @Bindable var kind: SmokeKind
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section(L("이름")) {
                TextField(L("예: 연초, 전자담배, 니코틴껌"), text: $kind.name)
            }
            Section(L("색상")) {
                KindColorGrid(selection: $kind.colorKey)
            }
            Section {
                Button(L("이 종류 삭제"), role: .destructive) {
                    confirmDelete = true
                }
                .tint(.red)
            }
        }
        .navigationTitle(kind.name.isEmpty ? L("새 종류") : kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("'%@' 종류를 삭제할까요?", kind.displayName), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("삭제"), role: .destructive) {
                context.delete(kind)
                dismiss()
            }
        }
        .onDisappear {
            // 방금 삭제했으면 손대지 않는다
            guard !kind.isDeleted, kind.modelContext != nil else { return }
            let trimmed = kind.name.trimmingCharacters(in: .whitespacesAndNewlines)
            kind.name = trimmed.isEmpty ? L("새 종류") : trimmed
        }
    }
}

/// 새 종류를 만든다. '종류 추가'를 눌러야 실제로 저장된다(그냥 나가면 아무것도 안 생김).
private struct NewKindView: View {
    let nextOrder: Int
    let usedColors: Set<String>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorKey = KindColor.teal.rawValue

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section(L("이름")) {
                TextField(L("예: 연초, 전자담배, 니코틴껌"), text: $name)
            }
            Section(L("색상")) {
                KindColorGrid(selection: $colorKey)
            }
            Section {
                Button {
                    let color = KindColor(rawValue: colorKey) ?? .teal
                    context.insert(SmokeKind(name: trimmedName, color: color, order: nextOrder))
                    dismiss()
                } label: {
                    Text(L("종류 추가"))
                        .frame(maxWidth: .infinity)
                }
                .disabled(trimmedName.isEmpty)
            }
        }
        .navigationTitle(L("새 종류"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 아직 안 쓴 색을 먼저 골라 둔다
            colorKey = (KindColor.allCases.first { !usedColors.contains($0.rawValue) } ?? .gray).rawValue
        }
    }
}

/// 종류 색 고르기
private struct KindColorGrid: View {
    @Binding var selection: String
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(KindColor.allCases) { option in
                Button {
                    selection = option.rawValue
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 40, height: 40)
                        .overlay {
                            if selection == option.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
