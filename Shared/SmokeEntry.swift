import Foundation
import SwiftData

/// 담배 한 개비 = 기록 하나. 누른 시각과 선택 메모를 저장하고, 통계는 시각에서 계산한다.
@Model
final class SmokeEntry {
    /// iCloud 동기화를 위해 모든 값에 기본값이 있어야 한다.
    var timestamp: Date = Date.now
    /// 기본값이 있어서 기존 데이터도 자동으로 옮겨진다(빈 메모).
    var memo: String = ""
    /// 연초·전자담배 등. 없으면 '종류 없음'.
    var kind: SmokeKind?

    init(timestamp: Date = .now, memo: String = "", kind: SmokeKind? = nil) {
        self.timestamp = timestamp
        self.memo = memo
        self.kind = kind
    }
}
