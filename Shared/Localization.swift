import Foundation

/// 앱 안에서 고르는 언어. 고르는 즉시 화면 전체가 바뀌도록 번역표를 직접 들고 있다.
/// (시스템 다국어 방식은 앱을 다시 켜야 바뀐다)
enum AppLanguage: String, CaseIterable, Identifiable {
    case ko, en

    var id: String { rawValue }
    static let key = "appLanguage"

    /// 저장된 값이 없으면 기기 언어를 따른다(한국어가 아니면 영어).
    /// 문구마다 설정을 읽으면 느려서, 읽은 값을 기억해 두고 설정이 바뀔 때만 다시 읽는다.
    static var current: AppLanguage {
        // 위젯은 앱과 따로 도는 프로그램이라 앱에서 바꾼 설정 알림을 못 받는다. 위젯에서는 매번 새로 읽는다.
        if LanguageCache.isExtension { return read() }
        if let cached = LanguageCache.value { return cached }
        let value = read()
        LanguageCache.value = value
        LanguageCache.observe()
        return value
    }

    private static func read() -> AppLanguage {
        let value: AppLanguage
        if let raw = AppStore.defaults.string(forKey: key), let lang = AppLanguage(rawValue: raw) {
            value = lang
        } else {
            value = Locale.preferredLanguages.first?.hasPrefix("ko") == true ? .ko : .en
        }
        return value
    }

    var locale: Locale { self == .ko ? Self.koLocale : Self.enLocale }
    private static let koLocale = Locale(identifier: "ko_KR")
    private static let enLocale = Locale(identifier: "en_US")
}

/// 언어 설정 값 기억. 설정이 바뀌면 지운다.
enum LanguageCache {
    nonisolated(unsafe) static var value: AppLanguage?
    nonisolated(unsafe) private static var observing = false
    /// 위젯 등 앱 확장(.appex)에서 도는 중인지
    static let isExtension = Bundle.main.bundleURL.pathExtension == "appex"

    static func observe() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { _ in
            let raw = AppStore.defaults.string(forKey: AppLanguage.key)
            if raw != value?.rawValue { value = nil }
        }
    }
}

extension Locale {
    /// 앱에서 고른 언어의 지역 설정 (날짜·요일 표기에 쓴다)
    static var app: Locale { AppLanguage.current.locale }
}

/// 한국어 문구를 지금 언어로 바꾼다. 번역이 없으면 한국어 그대로.
func L(_ ko: String) -> String {
    guard AppLanguage.current == .en else { return ko }
    return englishTable[ko] ?? ko
}

/// 숫자 등을 끼워 넣는 문구. 키는 한국어 형식 문자열(%d, %@, %.1f).
func L(_ ko: String, _ args: CVarArg...) -> String {
    let format = AppLanguage.current == .en ? (englishTable[ko] ?? ko) : ko
    return String(format: format, locale: Locale.app, arguments: args)
}

// MARK: - 영어 번역표

private let englishTable: [String: String] = [
    // 탭·공통
    "B흡연로그": "B Smoke Log",
    "달력": "Calendar",
    "통계": "Stats",
    "설정": "Settings",
    "취소": "Cancel",
    "저장": "Save",
    "삭제": "Delete",
    "확인": "OK",
    "완료": "Done",
    "선택": "Select",
    "개비": "",
    "%d개비": "%d",
    "%.1f개비": "%.1f",

    // 달력
    "이번 달": "This month",
    "오늘": "Today",
    "마지막 %@": "Last %@",
    "이달 하루 평균": "Daily average this month",
    "%@ 하루 평균": "Daily average in %@",
    "합계 %d개비": "Total %d",
    "지난달 평균 %.1f개비": "Last month %.1f per day",
    "지난달 기록 없음": "No entries last month",
    "날짜를 누르면 그날 기록 보기 · 꾹 누르면 추가, 삭제, 복사, 붙여넣기": "Tap a date to see its log · Press and hold to add, delete, copy, paste",
    "이 날에 이미 기록이 있어요": "This day already has entries",
    "기존 기록을 지우고 붙여넣기": "Replace existing entries",
    "기존 기록에 더하기": "Add to existing entries",
    "한 개비 추가": "Add one",
    "한 개비 삭제": "Delete one",
    "복사": "Copy",
    "붙여넣기": "Paste",
    "%@ 기록": "From %@",
    "%@에 기록했어요": "Logged at %@",
    "%@ 기록을 삭제했어요": "Deleted %@",
    "%@ 기록 %d개를 복사했어요": "Copied %2$d from %1$@",
    "%@에 %d개를 붙여넣었어요": "Pasted %2$d to %1$@",
    " (미래 시각 %d개 제외)": " (%d future skipped)",
    "실행 취소": "Undo",
    "누르면 기록을 보고, 길게 누르면 추가하거나 삭제합니다": "Tap to view, press and hold to add or delete",

    // 하루 기록
    "원형 시간표를 꾹 눌러서 손쉽게 추가/삭제가 가능해요.": "Press and hold the clock to add or delete.",
    "점을 클릭해 끌면 시간 변경이 가능해요.": "Drag a dot to change its time.",
    "합계": "Total",
    "기록이 없어요": "No entries",
    "기록": "Log",
    "시간": "Time",
    "메모 (선택)": "Note (optional)",
    "이 시간으로 추가": "Add at this time",
    "직접 추가": "Add manually",
    "전날": "Previous day",
    "다음날": "Next day",
    "선택 해제": "Deselect all",
    "전체 선택": "Select all",
    "%d개 삭제": "Delete %d",
    "선택한 기록 %d개를 삭제할까요?": "Delete %d selected entries?",
    "메모": "Note",
    "예: 커피 마시고, 회의 끝나고": "e.g. after coffee, after a meeting",
    "설정에서 종류를 추가할 수 있어요": "You can add types in Settings",
    "종류": "Type",
    "이 기록 삭제": "Delete this entry",
    "기록 편집": "Edit entry",
    "로 이동": "move here",
    "24시간 원형 기록표, %d개비": "24-hour log clock, %d entries",

    // 통계
    "1주": "1 week",
    "1개월": "1 month",
    "3개월": "3 months",
    "기간": "Period",
    "이 기간에는 기록이 없어요": "No entries in this period",
    "달력에서 오늘 날짜를 누르면 기록이 쌓여요.": "Your log builds up as you add entries in the calendar.",
    "전체": "All",
    "종류별": "By type",
    "최근 %@": "Last %@",
    "%d개 · %d%%": "%d · %d%%",
    "하루 평균": "Daily average",
    "%d일 기준": "Over %d days",
    "평균 간격": "Average gap",
    "6시간 이상 공백 제외": "Excludes gaps of 6h+",
    "자주 피는 시간": "Peak hour",
    "가장 많이 기록된 시간대": "Most logged hour",
    "직전 %@ 기간과 비슷해요.": "About the same as the previous %@.",
    "직전 %@ 기간보다 하루 %.1f개비 적어요.": "%2$.1f fewer per day than the previous %1$@.",
    "직전 %@ 기간보다 하루 %.1f개비 많아요.": "%2$.1f more per day than the previous %1$@.",
    "일별 기록": "Daily",
    "좌우로 넘겨 지난 기록 보기": "Swipe to see earlier days",
    "최근 %@ 평균 %.1f개비": "Last %@ average: %.1f",
    "시간대별": "By hour",
    "최근 %@ 합계": "Last %@ total",
    "%d시": "%dh",
    "요일별 평균": "By weekday",
    "종류 없음": "No type",

    // 설정
    "언어": "Language",
    "한국어": "Korean",
    "영어": "English",
    "기록할 때 진동": "Haptics when logging",
    "매주 일요일 저녁 8시에 알려줘요": "Every Sunday at 8 PM",
    "엑셀에서 열 수 있는 목록 파일로 저장해요": "A list file you can open in Excel",
    "다른 종류 %d개": "%d more types",
    "주간 한 줄 요약": "Weekly summary",
    "한 주의 시작": "Week starts on",
    "일요일": "Sunday",
    "월요일": "Monday",
    "하루 기준선": "Daily threshold",
    "이름 없음": "Untitled",
    "기본": "Default",
    "종류 추가": "Add type",
    "새 기록의 기본 종류": "Default type",
    "담배 종류": "Types",
    "iCloud 동기화": "iCloud sync",
    "앱을 다시 실행하면 적용돼요": "Takes effect after relaunching the app",
    "CSV 파일로 내보내기": "Export as CSV",
    "모든 기록 삭제": "Delete all entries",
    "데이터": "Data",
    "정보": "About",
    "버전": "Version",
    "이용약관 및 정책": "Terms & Policies",
    "준비 중": "Coming soon",
    "개발자의 다른 앱": "More apps by the developer",
    "알림이 꺼져 있어요": "Notifications are off",
    "아이폰 설정 > 알림에서 B흡연로그를 허용해 주세요.": "Allow notifications for B Smoke Log in iPhone Settings > Notifications.",
    "모든 기록을 삭제할까요?": "Delete all entries?",
    "모두 삭제": "Delete all",
    "기록 %d개가 지워지고 되돌릴 수 없어요.": "%d entries will be deleted. This can't be undone.",
    "날짜,시각,종류,메모": "Date,Time,Type,Note",
    "이름": "Name",
    "예: 연초, 전자담배, 니코틴껌": "e.g. Cigarette, E-cigarette, Nicotine gum",
    "색상": "Color",
    "이 종류 삭제": "Delete this type",
    "새 종류": "New type",
    "'%@' 종류를 삭제할까요?": "Delete the type '%@'?",

    // 기본 종류 이름 (처음 한 번 만들 때)
    "연초": "Cigarette",
    "전자담배": "E-cigarette",
    "니코틴껌": "Nicotine gum",

    // 위젯·알림
    "오늘 %d개비": "Today %d",
    "눌러서 +1": "Tap to +1",
    "한 개비": "One",
    "아직 기록이 없어요": "No entries yet",
    "한 개비 기록": "Log one",
    "오늘 개수를 보고, 누르면 바로 한 개비를 기록해요.": "See today's count and log one with a tap.",
    "지금 시각으로 한 개비를 기록해요.": "Logs one at the current time.",
    "기록했어요. 오늘 %d개비": "Logged. Today: %d",
    "이번 주": "This week",
    "이번 주 기록을 확인해 보세요.": "Take a look at this week's log.",
    "이번 주에는 기록이 없어요.": "No entries this week.",
    "이번 주 하루 평균 %.1f개비": "This week: %.1f per day",
    ", 지난주와 비슷해요.": ", about the same as last week.",
    ", 지난주보다 하루 %.1f개비 적어요.": ", %.1f fewer per day than last week.",
    ", 지난주보다 하루 %.1f개비 많아요.": ", %.1f more per day than last week.",

    // 시간 표현
    "방금 전": "just now",
    "%d분": "%dm",
    "%d시간": "%dh",
    "%d시간 %d분": "%dh %dm",
    "%d일 전": "%dd ago",
    "%@ 전": "%@ ago",
]
