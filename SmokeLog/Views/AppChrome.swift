import SwiftUI

// MARK: - 설정 열기 (각 화면 오른쪽 위 톱니바퀴)

private struct ShowSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct OpenDayKey: EnvironmentKey {
    static let defaultValue: (Date) -> Void = { _ in }
}

extension EnvironmentValues {
    /// 그 날을 '오늘' 화면에서 연다 (달력에서 날짜를 눌렀을 때)
    var openDay: (Date) -> Void {
        get { self[OpenDayKey.self] }
        set { self[OpenDayKey.self] = newValue }
    }

    /// 설정 창을 연다. 맨 위 화면(ContentView)이 채워 준다.
    var showSettings: () -> Void {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }
}

/// 오른쪽 위 설정 아이콘
struct SettingsButton: View {
    @Environment(\.showSettings) private var showSettings

    var body: some View {
        Button(action: showSettings) {
            Image(systemName: "gearshape")
                .font(.title3)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L("설정"))
    }
}

// MARK: - 아래 메뉴 (오늘 · 달력 · 통계)

extension BottomTabBar {
    /// 화면 내용이 아래 메뉴에 가리지 않도록 맨 아래에 남겨 둘 여백
    static let contentInset: CGFloat = 100
}

enum AppTab: Int, CaseIterable {
    case today, calendar, stats

    var title: String {
        switch self {
        case .calendar: L("달력")
        case .today: L("오늘")
        case .stats: L("통계")
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .today: "clock"
        case .stats: "chart.bar.xaxis"
        }
    }
}

/// 좌우로 넘기는 화면과 함께 쓰는 아래 메뉴. 고른 칸에 은은한 배경이 따라 움직인다.
struct BottomTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button {
                    withAnimation(.snappy) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selected ? Color.brand : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 48)
        .padding(.bottom, 4)
    }
}
