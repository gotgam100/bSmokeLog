import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

@main
struct SmokeLogApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try AppStore.makeAppContainer()
        } catch {
            fatalError("데이터 저장소를 열 수 없습니다: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            SampleData.seed(into: container.mainContext)
        }
        #endif
        KindStore.seedIfNeeded(container.mainContext)
        AppStore.refreshICloudAvailability()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-randomizeKinds") {
            SampleData.randomizeKinds(in: container.mainContext)
        }
        if ProcessInfo.processInfo.arguments.contains("-seedHeavy") {
            DebugTools.seedHeavy(container.mainContext)
        }
        if ProcessInfo.processInfo.arguments.contains("-hangWatch") {
            DebugTools.startHangWatch()
        }
        // 위젯·제어 센터와 같은 +1 동작을 앱 밖에서처럼 실행해 본다(확인용)
        if ProcessInfo.processInfo.arguments.contains("-runAddIntent") {
            Task { @MainActor in _ = try? await AddSmokeIntent().perform() }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, .app)
                .tint(.brand)
        }
        .modelContainer(container)
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .today
    @State private var showSettings = false
    /// '오늘' 화면에 보이는 날
    @State private var shownDay = Calendar.app.startOfDay(for: .now)
    /// 위젯 등 앱 밖에서 기록이 바뀌면 화면을 새로 읽기 위한 값
    @State private var refreshID = 0
    @State private var seenExternalChange = AppStore.defaults.double(forKey: AppStore.Key.externalChange)
    /// 언어를 바꾸면 화면 전체를 새 언어로 다시 그린다
    @AppStorage(AppLanguage.key, store: AppStore.defaults) private var language = AppLanguage.current.rawValue

    var body: some View {
        // 세 화면을 좌우로 넘긴다. 아래 메뉴로도 옮겨 갈 수 있다.
        TabView(selection: $tab) {
            TodayView(day: $shownDay)
                .id(refreshID)
                .tag(AppTab.today)
            CalendarView()
                .id(refreshID)
                .tag(AppTab.calendar)
            StatsView()
                .id(refreshID)
                .tag(AppTab.stats)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomTabBar(selection: $tab)
        }
        .environment(\.showSettings, { showSettings = true })
        .environment(\.openDay, { day in
            shownDay = Calendar.app.startOfDay(for: day)
            withAnimation(.snappy) { tab = .today }
        })
        .sheet(isPresented: $showSettings) {
            SettingsView { showSettings = false }
        }
        .id(language)
        .environment(\.locale, .app)
        .preferredColorScheme(.dark)  // 이 앱은 다크 모드 하나로만 쓴다
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                let changed = AppStore.defaults.double(forKey: AppStore.Key.externalChange)
                if changed > seenExternalChange {
                    seenExternalChange = changed
                    refreshID += 1
                }
                WeeklySummary.reschedule(context: context)
            case .background:
                try? context.save()
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
        .onChange(of: language) {
            // 위젯·주간 알림 문구도 새 언어로
            WidgetCenter.shared.reloadAllTimelines()
            WeeklySummary.reschedule(context: context)
        }
        // 기록이 저장될 때마다 위젯·주간 알림을 맞춘다 (전체 기록을 들고 있지 않고 저장 알림만 받는다)
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            WidgetCenter.shared.reloadAllTimelines()
            WeeklySummary.reschedule(context: context)
        }
    }
}

/// 단축어·액션 버튼·Siri에서 쓸 수 있는 동작
struct SmokeLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddSmokeIntent(),
            phrases: [
                "\(.applicationName)에 한 개비 기록",
                "\(.applicationName) 기록"
            ],
            shortTitle: "한 개비 기록",
            systemImageName: "plus.circle"
        )
    }
}
