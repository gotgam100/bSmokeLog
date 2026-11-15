import SwiftUI
import SwiftData
import UIKit

/// 24시간을 두꺼운 도넛 24칸으로 나누고, 피운 시각을 표시한다(히트맵).
/// 0시가 맨 위, 시계 방향으로 진행. 피운 시간대 칸이 개수만큼 진해지고, 정확한 시각은 칸 위 점으로 찍힌다.
/// 가운데에는 합계, 마지막 기록이 언제였는지(오늘이면 "23분 전"), 어제 이맘때와의 비교가 보인다.
/// - 어디든 꾹 누르면 살짝 눌리는 느낌과 함께 메뉴(한 개비 추가 · 한 개비 삭제)가 뜬다.
///   고리 위면 누른 자리의 시각, 가운데면 지금 시각이 기준이 된다.
/// - 점을 꾹 누르자마자(메뉴가 뜨기 전에) 끌면 그 기록의 시각이 바뀐다. 살짝 닿기만 해서는 안 움직인다.
struct DayClockView: View {
    let entries: [SmokeEntry]
    /// 그 날의 0시
    let dayStart: Date
    /// 옮길 수 있는 가장 늦은 시각 (오늘이면 현재 시각)
    let latest: Date
    /// 어제 이맘때까지의 개수 (지난 날이면 전날 하루 전체)
    let previousCount: Int
    let onMove: (SmokeEntry, Date) -> Void
    let onAdd: (Date) -> Void
    let onDelete: (SmokeEntry) -> Void

    @State private var draggingID: PersistentIdentifier?
    @State private var dragHour: Double = 0

    private let cal = Calendar.app
    /// 점을 이만큼 누르고 있다가 끌어야 움직인다. 바로 쓸면 스크롤.
    /// 약 0.35초가 지나면 꾹 누르기 메뉴가 터치를 가져가므로 그보다 충분히 짧게 둔다.
    private static let pressDuration = 0.15

    private var activeHour: Double? {
        draggingID != nil ? dragHour : nil
    }

    var body: some View {
        let hours = entries.map(displayHour)
        let hourly = hourlyCounts(hours)
        let hourColors = dominantColors()
        let maxCount = max(hourly.max() ?? 0, 1)

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outer = size / 2
            let labelRadius = outer - 10
            // 두꺼운 도넛: 고리 두께와 가운데 반지름
            let ringWidth = size * 0.2
            let ringRadius = outer - 26 - ringWidth / 2
            let ringOuter = ringRadius + ringWidth / 2
            let holeRadius = ringRadius - ringWidth / 2
            let dotRadius = ringOuter - 11

            let face = ZStack {
                // 24칸 히트맵 도넛 (칸 사이 살짝 틈)
                ForEach(0..<24, id: \.self) { hour in
                    let count = hourly[hour]
                    Segment(center: center, radius: ringRadius, startHour: Double(hour) + 0.035, endHour: Double(hour) + 0.965)
                        .stroke(count > 0
                                ? hourColors[hour].opacity(0.3 + 0.55 * Double(count) / Double(maxCount))
                                : Color(.tertiarySystemFill),
                                lineWidth: ringWidth)
                }

                // 옮기는 중인 시간대 칸을 함께 밝힌다
                if draggingID != nil {
                    let h = Double(min(23, max(0, Int(dragHour))))
                    Segment(center: center, radius: ringRadius, startHour: h + 0.035, endHour: h + 0.965)
                        .stroke(Color.orange.opacity(0.35), lineWidth: ringWidth)
                        .allowsHitTesting(false)
                }

                // 바깥 시각 숫자
                ForEach(0..<24, id: \.self) { hour in
                    let major = hour % 6 == 0
                    Text("\(hour)")
                        .font(.system(size: major ? 12 : 9, weight: major ? .bold : .regular))
                        .foregroundStyle(major ? Color.primary : Color.secondary)
                        .position(point(center: center, radius: labelRadius, hour: Double(hour)))
                }

                // 가운데: 합계와 종류별 개수 (조작 중에는 시각)
                centerLabel
                    .frame(width: holeRadius * 1.8)
                    .position(center)

                // 오늘이면 지금 시각에 노란 선 (5분마다 다시 그림)
                if cal.isDateInToday(dayStart) {
                    TimelineView(.periodic(from: .now, by: 300)) { context in
                        let h = context.date.timeIntervalSince(dayStart) / 3600
                        Path { p in
                            p.move(to: point(center: center, radius: holeRadius - 4, hour: h))
                            p.addLine(to: point(center: center, radius: ringOuter + 4, hour: h))
                        }
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                    .allowsHitTesting(false)
                }

                // 피운 시각 점 (꾹 눌러서 끌기)
                ForEach(entries, id: \.persistentModelID) { entry in
                    let isDragging = draggingID == entry.persistentModelID
                    ZStack {
                        if isDragging {
                            // 잡힌 점 뒤로 은은한 배경
                            Circle()
                                .fill(Color.orange.opacity(0.25))
                                .frame(width: 40, height: 40)
                        }
                        Circle()
                            .fill(isDragging ? Color.orange : entry.color)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                            .frame(width: isDragging ? 18 : 10, height: isDragging ? 18 : 10)
                    }
                    .modifier(Wiggle(active: isDragging))
                    .position(point(center: center, radius: dotRadius, hour: displayHour(entry)))
                    .zIndex(isDragging ? 1 : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.spring(duration: 0.2), value: draggingID)

            // 꾹 누르기 메뉴와 점 끌기는 UIKit으로 받는다.
            // (SwiftUI 기본 메뉴에는 iOS가 'Siri에게 요청하기'를 덧붙여서, 메뉴 항목을 직접 정한다)
            ClockInteractionHost(
                content: AnyView(face.environment(\.locale, .app)),
                holdDuration: Self.pressDuration,
                canBegin: { hitEntry(at: $0, center: center, dotRadius: dotRadius) != nil },
                onPan: { handlePress($0, at: $1, center: center, dotRadius: dotRadius) },
                makeMenu: { makeMenu(at: $0, center: center, holeRadius: holeRadius, dotRadius: dotRadius) }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .sensoryFeedback(.impact(weight: .medium), trigger: draggingID != nil) { _, new in new }
        .sensoryFeedback(.selection, trigger: activeHour.map { Int($0) } ?? -1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("24시간 원형 기록표, %d개비", entries.count))
    }

    // MARK: - 제스처

    /// 점을 잠깐 누른 뒤 끌 때만 불린다(HoldPanRecognizer). 손을 떼면 그 시각으로 옮긴다.
    private func handlePress(_ state: UIGestureRecognizer.State, at location: CGPoint, center: CGPoint, dotRadius: CGFloat) {
        let hour = clamp(hour(at: location, center: center))
        switch state {
        case .began:
            if let hit = hitEntry(at: location, center: center, dotRadius: dotRadius) {
                dragHour = hour
                draggingID = hit.persistentModelID
            }
        case .changed:
            if draggingID != nil { dragHour = hour }
        case .ended:
            if let id = draggingID, let entry = entries.first(where: { $0.persistentModelID == id }) {
                onMove(entry, date(for: dragHour))
            }
            draggingID = nil
        default:
            draggingID = nil
        }
    }

    private func hitEntry(at location: CGPoint, center: CGPoint, dotRadius: CGFloat) -> SmokeEntry? {
        entries
            .map { ($0, distance(point(center: center, radius: dotRadius, hour: baseHour($0)), location)) }
            .filter { $0.1 < 22 }
            .min { $0.1 < $1.1 }?.0
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// 평소엔 합계와 전날 비교, 조작 중엔 옮기거나 추가할 시각. 전환 애니메이션 없이 즉시 바뀐다.
    private var centerLabel: some View {
        let hour = activeHour
        let timeText = date(for: hour ?? 0).formatted(Date.FormatStyle(locale: .app).hour().minute())
        return VStack(spacing: 2) {
            // 숫자와 '개비'를 한 줄에 (글자 크기는 그대로)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(hour != nil ? timeText : "\(entries.count)")
                    .font(.system(size: hour != nil ? 22 : 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(hour != nil ? Color.orange : Color.primary)
                Text(hour != nil ? L("로 이동") : L("개비"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if hour == nil {
                comparison
                    .padding(.top, 6)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .transaction { $0.animation = nil }
    }

    /// 어제 이맘때(지난 날이면 전날)와 비교해 얼마나 늘거나 줄었는지. 많으면 빨간 ▲, 적으면 파란 ▼, 같으면 회색 −.
    private var comparison: some View {
        let diff = entries.count - previousCount
        let color: Color = diff > 0 ? .red : diff < 0 ? .blue : .secondary
        return HStack(spacing: 3) {
            Text(cal.isDateInToday(dayStart) ? L("어제 이맘때보다") : L("전날보다"))
                .foregroundStyle(.secondary)
            Text("\(abs(diff))")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
            Image(systemName: diff > 0 ? "arrow.up" : diff < 0 ? "arrow.down" : "minus")
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
        .font(.caption)
    }

    /// 꾹 누른 자리 기준 메뉴: 한 개비 추가 · 한 개비 삭제
    private func makeMenu(at location: CGPoint, center: CGPoint, holeRadius: CGFloat, dotRadius: CGFloat) -> UIMenu {
        // 점 위면 그 기록, 가운데면 지금 시각, 그 밖의 빈 곳이면 누른 자리의 시각
        // (삭제 대상은 같은 시간대에서 가장 가까운 기록)
        let hour: Double
        let target: SmokeEntry?
        if let hit = hitEntry(at: location, center: center, dotRadius: dotRadius) {
            hour = baseHour(hit)
            target = hit
        } else {
            hour = distance(location, center) <= holeRadius ? clamp(currentHour) : clamp(self.hour(at: location, center: center))
            target = entries
                .filter { Int(baseHour($0)) == Int(hour) }
                .min { abs(baseHour($0) - hour) < abs(baseHour($1) - hour) }
        }
        let tint = UIColor(Color.brand)
        func icon(_ name: String) -> UIImage? {
            UIImage(systemName: name)?.withTintColor(tint, renderingMode: .alwaysOriginal)
        }
        let add = UIAction(title: L("한 개비 추가"), subtitle: "(\(timeText(hour)))", image: icon("plus.circle")) { _ in
            onAdd(date(for: hour))
        }
        let delete = UIAction(
            title: L("한 개비 삭제"),
            subtitle: target.map { "(\(timeText(baseHour($0))))" },
            image: icon("minus.circle"),
            attributes: target == nil ? [.destructive, .disabled] : [.destructive]
        ) { _ in
            if let target { onDelete(target) }
        }
        return UIMenu(children: [add, delete])
    }

    /// 지금 시각(시 단위). 다른 날을 보고 있으면 그날의 같은 시각.
    private var currentHour: Double {
        let c = cal.dateComponents([.hour, .minute], from: .now)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private func timeText(_ hour: Double) -> String {
        date(for: hour).formatted(Date.FormatStyle(locale: .app).hour().minute())
    }

    private func date(for hour: Double) -> Date {
        dayStart.addingTimeInterval((hour * 60).rounded() * 60)
    }

    // MARK: - 계산

    private func displayHour(_ entry: SmokeEntry) -> Double {
        if draggingID == entry.persistentModelID { return dragHour }
        return baseHour(entry)
    }

    private func baseHour(_ entry: SmokeEntry) -> Double {
        let c = cal.dateComponents([.hour, .minute], from: entry.timestamp)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    /// 시간대마다 가장 많이 기록된 종류의 색
    private func dominantColors() -> [Color] {
        var result = Array(repeating: Color.brand, count: 24)
        let grouped = Dictionary(grouping: entries) { min(23, max(0, Int(displayHour($0)))) }
        for (hour, items) in grouped {
            let byKind = Dictionary(grouping: items) { $0.kind?.id }
            if let top = byKind.max(by: { $0.value.count < $1.value.count })?.value.first {
                result[hour] = top.color
            }
        }
        return result
    }

    private func hourlyCounts(_ hours: [Double]) -> [Int] {
        var result = Array(repeating: 0, count: 24)
        for h in hours { result[min(23, max(0, Int(h)))] += 1 }
        return result
    }

    /// 손가락 위치 → 0..<24 시
    private func hour(at location: CGPoint, center: CGPoint) -> Double {
        let degrees = atan2(location.y - center.y, location.x - center.x) * 180 / .pi + 90
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return normalized / 15
    }

    /// 미래로는 못 가게 막는다.
    private func clamp(_ hour: Double) -> Double {
        let maxHour = min(latest.timeIntervalSince(dayStart) / 3600, 24 - 1.0 / 60)
        return min(max(hour, 0), maxHour)
    }

    private func point(center: CGPoint, radius: CGFloat, hour: Double) -> CGPoint {
        let angle = Angle.degrees(hour * 15 - 90).radians
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

/// 잡힌 점이 살짝 흔들린다(앱 아이콘 편집 때처럼).
private struct Wiggle: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([-1.0, 1.0]) { view, phase in
                view
                    .rotationEffect(.degrees(phase * 8))
                    .offset(x: phase * 1.2)
            } animation: { _ in .easeInOut(duration: 0.12) }
        } else {
            content
        }
    }
}

/// 도넛 한 칸이 되는 호. hour 단위 각도(1시간 = 15°), 0시가 위쪽. 두껍게 stroke해서 칸을 만든다.
private struct Segment: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startHour: Double
    let endHour: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: center, radius: radius,
                 startAngle: .degrees(startHour * 15 - 90),
                 endAngle: .degrees(endHour * 15 - 90),
                 clockwise: false)
        return p
    }
}

/// 원형 시간표를 UIKit 뷰 안에 담아, 꾹 누르기 메뉴와 점 끌기를 직접 처리한다.
/// 좌표는 모두 이 뷰 기준이라 스크롤·시트 위치와 상관없이 정확하다.
private struct ClockInteractionHost: UIViewRepresentable {
    let content: AnyView
    let holdDuration: TimeInterval
    let canBegin: (CGPoint) -> Bool
    let onPan: (UIGestureRecognizer.State, CGPoint) -> Void
    let makeMenu: (CGPoint) -> UIMenu

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let coordinator = context.coordinator
        coordinator.parent = self

        let view = UIView()
        view.backgroundColor = .clear

        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        coordinator.host = host

        let pan = HoldPanRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.holdDuration = holdDuration
        pan.maximumNumberOfTouches = 1
        pan.delegate = pan
        pan.canBegin = { [weak coordinator] point in coordinator?.parent?.canBegin(point) ?? false }
        view.addGestureRecognizer(pan)

        // 손이 닿자마자 살짝 눌리는 느낌 (메뉴가 뜨거나 손을 떼면 되돌아온다)
        let press = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePress(_:)))
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        press.delegate = coordinator
        view.addGestureRecognizer(press)

        view.addInteraction(UIContextMenuInteraction(delegate: coordinator))
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.host?.rootView = content
    }

    final class Coordinator: NSObject, UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate {
        var parent: ClockInteractionHost?
        var host: UIHostingController<AnyView>?

        @objc func handlePress(_ recognizer: UILongPressGestureRecognizer) {
            guard let view = host?.view else { return }
            let pressed = recognizer.state == .began || recognizer.state == .changed
            UIView.animate(withDuration: pressed ? 0.12 : 0.25, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }

        /// 눌림 효과는 스크롤·끌기·메뉴와 함께 인식된다 (다른 동작을 막지 않는다)
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            // 점을 끌기 시작하면 떠오르던 메뉴는 접는다
            if recognizer.state == .began {
                recognizer.view?.interactions
                    .compactMap { $0 as? UIContextMenuInteraction }
                    .forEach { $0.dismissMenu() }
            }
            parent?.onPan(recognizer.state, recognizer.location(in: recognizer.view))
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            guard let parent else { return nil }
            // 시스템이 덧붙이는 추천 항목(suggestedActions)은 쓰지 않는다
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                parent.makeMenu(location)
            }
        }

        /// 떠오르는 미리보기는 원형표 그대로(배경색 없이) 보여 준다.
        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configuration: UIContextMenuConfiguration,
                                    highlightPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
            guard let view = interaction.view else { return nil }
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.shadowPath = UIBezierPath()
            parameters.visiblePath = UIBezierPath(ovalIn: view.bounds.insetBy(dx: -4, dy: -4))
            return UITargetedPreview(view: view, parameters: parameters)
        }
    }
}

/// 점을 잠깐(holdDuration) 누르고 있다가 끌 때만 시작하는 끌기.
/// 바로 쓸면 스크롤, 더 오래 누르고 있으면 메뉴가 뜬다.
private final class HoldPanRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    var holdDuration: TimeInterval = 0.25
    var canBegin: ((CGPoint) -> Bool)?
    private var downTime: TimeInterval = 0
    private var downLocation: CGPoint = .zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            downTime = touch.timestamp
            downLocation = touch.location(in: view)
        }
        super.touchesBegan(touches, with: event)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard ProcessInfo.processInfo.systemUptime - downTime >= holdDuration else { return false }
        return canBegin?(downLocation) ?? false
    }

    /// 스크롤은 이 끌기가 포기한 뒤에만 시작한다(점 위에서 잠깐 누른 뒤 끌면 점이 움직이도록).
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        other.view is UIScrollView
    }
}
