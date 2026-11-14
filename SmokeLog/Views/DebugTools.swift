#if DEBUG
import Foundation
import SwiftData
import os

/// 확인용 도구 (디버그 빌드에서만).
enum DebugTools {
    private static let log = Logger(subsystem: "com.seunghwabaek.bsmokelog", category: "perf")

    /// 화면(메인 스레드)이 100ms 넘게 멈추면 로그를 남긴다. `-hangWatch` 실행 인자로 켠다.
    static func startHangWatch() {
        let thread = Thread {
            while true {
                let sent = DispatchTime.now()
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { sem.signal() }
                sem.wait()
                let ms = Double(DispatchTime.now().uptimeNanoseconds - sent.uptimeNanoseconds) / 1_000_000
                if ms > 100 { log.notice("HANG \(Int(ms), privacy: .public)ms") }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// 약 3년치 기록(하루 8~16개)을 넣는다. `-seedHeavy` 실행 인자로 켠다. 이미 5000개 넘으면 건너뛴다.
    @MainActor
    static func seedHeavy(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<SmokeEntry>())) ?? 0
        guard existing < 5000 else { return }
        let kinds = (try? context.fetch(FetchDescriptor<SmokeKind>())) ?? []
        let cal = Calendar.app
        let today = cal.startOfDay(for: .now)
        for offset in 1...1095 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            for _ in 0..<Int.random(in: 8...16) {
                let minute = Int.random(in: (7 * 60)...(24 * 60 - 1))
                context.insert(SmokeEntry(timestamp: day.addingTimeInterval(TimeInterval(minute * 60)),
                                          kind: kinds.randomElement()))
            }
        }
        try? context.save()
    }
}
#endif
