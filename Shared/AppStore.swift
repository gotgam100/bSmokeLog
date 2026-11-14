import Foundation
import SwiftData
import CloudKit

/// 앱과 위젯이 함께 쓰는 저장소·설정.
/// - 기록은 App Group 공유 폴더에 둔다(위젯·제어 센터에서 +1 하려면 필요).
/// - App Group을 쓸 수 없는 환경이면 예전처럼 앱 안에 저장한다.
enum AppStore {
    static let groupID = "group.com.seunghwabaek.bsmokelog"
    static let cloudContainerID = "iCloud.com.seunghwabaek.bsmokelog"

    /// 앱·위젯이 함께 보는 설정 저장소
    static let defaults: UserDefaults = UserDefaults(suiteName: groupID) ?? .standard

    enum Key {
        static let defaultKindID = "defaultKindID"
        static let kindsSeeded = "kindsSeeded"
        static let iCloudSync = "iCloudSync"
        static let dailyLimit = "dailyLimit"
        static let weeklySummary = "weeklySummary"
        /// 위젯 등 앱 밖에서 기록을 바꾼 시각. 앱이 다시 열릴 때 화면을 새로 읽는 데 쓴다.
        static let externalChange = "externalChange"
        /// 마지막으로 확인한 iCloud 사용 가능 여부 (앱 실행 때마다 뒤에서 다시 확인)
        static let iCloudAvailable = "iCloudAvailable"
    }

    private static var groupFolder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
    }

    /// 예전(앱 전용) 저장 위치
    private static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    static var storeURL: URL {
        guard let folder = groupFolder else { return legacyStoreURL }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "SmokeLog.store")
    }

    /// 앱용 저장소. iCloud 설정이 켜져 있으면 iCloud로 동기화하고, 안 되면 기기에만 저장한다.
    /// 앱·위젯이 같은 파일을 열므로 스키마도 한곳에서 정한다
    static let schema = Schema([SmokeEntry.self, SmokeKind.self, ExcludedDay.self])

    static func makeAppContainer() throws -> ModelContainer {
        migrateLegacyStoreIfNeeded()
        migrateDefaultsIfNeeded()
        let wantsCloud = defaults.object(forKey: Key.iCloudSync) as? Bool ?? true
        // iCloud에 로그인돼 있지 않은데 동기화를 켜면 실행할 때 화면이 몇 초씩 멈춘다.
        // 지난번 실행에서 iCloud를 쓸 수 있다고 확인됐을 때만 켠다.
        if wantsCloud && defaults.bool(forKey: Key.iCloudAvailable) {
            let cloud = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .private(cloudContainerID))
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                return container
            }
        }
        let local = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: local)
    }

    /// 위젯·단축어용 저장소 (같은 파일을 연다. 동기화는 앱이 맡는다)
    static func makeExtensionContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    private static let legacyMigratedKey = "legacyStoreMigrated"

    /// 앱 전용 위치에 있던 기록을 공유 폴더로 옮긴다. 원본은 지우지 않는다.
    /// - 새 저장소가 아직 없으면 파일째 복사
    /// - 이미 있으면(위젯이 먼저 만들었거나 등) 기록을 하나씩 옮겨 담는다
    private static func migrateLegacyStoreIfNeeded() {
        let fm = FileManager.default
        let target = storeURL
        let legacyPath = legacyStoreURL.path(percentEncoded: false)
        guard target != legacyStoreURL,
              !defaults.bool(forKey: legacyMigratedKey),
              fm.fileExists(atPath: legacyPath) else { return }

        if !fm.fileExists(atPath: target.path(percentEncoded: false)) {
            for suffix in ["", "-shm", "-wal"] {
                let from = legacyPath + suffix
                if fm.fileExists(atPath: from) {
                    try? fm.copyItem(atPath: from, toPath: target.path(percentEncoded: false) + suffix)
                }
            }
            defaults.set(true, forKey: legacyMigratedKey)
            return
        }
        if MainActor.assumeIsolated({ mergeLegacyRecords(into: target) }) {
            defaults.set(true, forKey: legacyMigratedKey)
        }
    }

    @MainActor
    private static func mergeLegacyRecords(into target: URL) -> Bool {
        guard let old = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: legacyStoreURL, cloudKitDatabase: .none)),
              let new = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: target, cloudKitDatabase: .none)) else {
            return false
        }
        let from = old.mainContext, to = new.mainContext
        let oldKinds = (try? from.fetch(FetchDescriptor<SmokeKind>())) ?? []
        let newKinds = (try? to.fetch(FetchDescriptor<SmokeKind>())) ?? []
        var kindMap: [UUID: SmokeKind] = Dictionary(newKinds.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for k in oldKinds where kindMap[k.id] == nil {
            let copy = SmokeKind(name: k.name, color: KindColor(rawValue: k.colorKey) ?? .teal, order: k.order)
            copy.id = k.id
            to.insert(copy)
            kindMap[k.id] = copy
        }
        let existing = Set(((try? to.fetch(FetchDescriptor<SmokeEntry>())) ?? []).map(\.timestamp))
        for e in (try? from.fetch(FetchDescriptor<SmokeEntry>())) ?? [] where !existing.contains(e.timestamp) {
            to.insert(SmokeEntry(timestamp: e.timestamp, memo: e.memo, kind: e.kind.flatMap { kindMap[$0.id] }))
        }
        do { try to.save(); return true } catch { return false }
    }

    /// 예전에 앱 설정(standard)에 저장하던 값을 공유 설정으로 옮긴다.
    private static func migrateDefaultsIfNeeded() {
        guard defaults !== UserDefaults.standard else { return }
        for key in [Key.defaultKindID, Key.kindsSeeded] where defaults.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }

    /// iCloud 계정 상태를 뒤에서 확인해 다음 실행 때 쓸 수 있게 기억해 둔다.
    static func refreshICloudAvailability() {
        // 화면이 다 뜬 뒤 백그라운드에서 확인한다 (CloudKit 준비가 화면을 붙잡지 않도록)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
            CKContainer(identifier: cloudContainerID).accountStatus { status, _ in
                defaults.set(status == .available, forKey: Key.iCloudAvailable)
            }
        }
    }
}
