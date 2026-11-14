import SwiftUI

/// 각 화면(오늘·달력·통계·설정) 맨 위 제목. 모두 같은 글꼴·위치를 쓰도록 한곳에 둔다.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Color(.label))
                .textCase(nil)
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

extension ScreenTitle {
    /// 제목 위 여백 (모든 화면 공통)
    static var topPadding: CGFloat { 16 }
}
