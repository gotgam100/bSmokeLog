import AppIntents
import SwiftData
import WidgetKit

/// 앱을 열지 않고 지금 시각으로 한 개비를 기록한다.
/// 위젯 버튼, 제어 센터·잠금 화면 컨트롤, 액션 버튼, 단축어에서 같은 동작을 쓴다.
struct AddSmokeIntent: AppIntent {
    static let title: LocalizedStringResource = "한 개비 기록"
    static let description = IntentDescription("지금 시각으로 한 개비를 기록해요.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try AppStore.makeExtensionContainer()
        let context = container.mainContext
        context.insert(SmokeEntry(timestamp: .now, kind: KindStore.defaultKind(context)))
        try context.save()

        let start = Calendar.app.startOfDay(for: .now)
        let todayCount = (try? context.fetchCount(FetchDescriptor<SmokeEntry>(
            predicate: #Predicate { $0.timestamp >= start }
        ))) ?? 0

        AppStore.defaults.set(Date.now.timeIntervalSince1970, forKey: AppStore.Key.externalChange)
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result(dialog: IntentDialog(stringLiteral: L("기록했어요. 오늘 %d개비", todayCount)))
    }
}
