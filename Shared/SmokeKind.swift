import SwiftUI
import SwiftData

/// 담배 종류 (연초, 전자담배, 니코틴껌 …). 설정에서 이름과 색을 정한다.
@Model
final class SmokeKind {
    var id: UUID = UUID()
    var name: String = ""
    /// KindColor의 rawValue
    var colorKey: String = KindColor.teal.rawValue
    var order: Int = 0
    /// 종류를 지우면 그 기록들은 '종류 없음'이 된다(기록 자체는 남는다).
    @Relationship(deleteRule: .nullify, inverse: \SmokeEntry.kind)
    var entries: [SmokeEntry]? = []

    init(name: String, color: KindColor, order: Int) {
        self.id = UUID()
        self.name = name
        self.colorKey = color.rawValue
        self.order = order
    }

    /// 화면에 보이는 이름. 기본 종류(연초·전자담배·니코틴껌)는 고른 언어로, 직접 지은 이름은 그대로.
    var displayName: String { L(name) }

    var color: Color { (KindColor(rawValue: colorKey) ?? .teal).color }
}

/// 종류에 고를 수 있는 색
enum KindColor: String, CaseIterable, Identifiable {
    case teal, orange, purple, pink, blue, green, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal: .teal
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        case .blue: .blue
        case .green: .green
        case .brown: .brown
        case .gray: .gray
        }
    }
}

extension SmokeEntry {
    /// 종류의 색. 종류가 없으면(지워졌거나 안 고름) 회색.
    var color: Color { kind?.color ?? .gray }
}

enum KindStore {
    static let defaultKey = AppStore.Key.defaultKindID
    private static let seededKey = AppStore.Key.kindsSeeded

    /// 처음 한 번만 기본 종류를 만들고, 그 전에 쌓인 기록은 '연초'로 둔다.
    /// 사용자가 종류를 모두 지워도 다시 만들지 않는다.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = AppStore.defaults
        guard !defaults.bool(forKey: seededKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<SmokeKind>())) ?? 0
        if existing == 0 {
            let cigarette = SmokeKind(name: L("연초"), color: .teal, order: 0)
            context.insert(cigarette)
            context.insert(SmokeKind(name: L("전자담배"), color: .purple, order: 1))
            context.insert(SmokeKind(name: L("니코틴껌"), color: .green, order: 2))
            let entries = (try? context.fetch(FetchDescriptor<SmokeEntry>())) ?? []
            for entry in entries where entry.kind == nil { entry.kind = cigarette }
            defaults.set(cigarette.id.uuidString, forKey: defaultKey)
        }
        try? context.save()
        defaults.set(true, forKey: seededKey)
    }

    /// 실행 취소용: 아직 남아 있는 기록만 지운다(그 사이 다른 화면에서 지웠을 수 있음).
    @MainActor
    static func deleteEntries(_ ids: [PersistentIdentifier], in context: ModelContext) {
        let wanted = Set(ids)
        let alive = (try? context.fetch(FetchDescriptor<SmokeEntry>())) ?? []
        for entry in alive where wanted.contains(entry.persistentModelID) {
            context.delete(entry)
        }
    }

    /// id로 종류를 찾는다. 그 사이 지워졌으면 nil.
    @MainActor
    static func kind(id: UUID?, in context: ModelContext) -> SmokeKind? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<SmokeKind>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first { !$0.isDeleted }
    }

    /// 새 기록에 붙일 종류: 설정의 '기본 종류', 없으면 맨 위 종류.
    @MainActor
    static func defaultKind(_ context: ModelContext) -> SmokeKind? {
        let kinds = ((try? context.fetch(FetchDescriptor<SmokeKind>(sortBy: [SortDescriptor(\.order)]))) ?? []).filter { !$0.isDeleted }
        let id = AppStore.defaults.string(forKey: defaultKey)
        return kinds.first { $0.id.uuidString == id } ?? kinds.first
    }
}
