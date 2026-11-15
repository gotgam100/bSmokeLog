// 앱스토어 스크린샷(문구 + 기기 화면)을 한국어·영어로 만든다.
// 원본은 raw-ko/, raw-en/ 에 있는 시뮬레이터 캡처(1320x2868, 실행 인자 -screenshotData).
// 헤더·검색 결과 이미지는 make_creative.swift가 만든다.
// 실행: swift design/appstore/make_screenshots.swift
import AppKit

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

// MARK: - 색과 글꼴

let teal = NSColor(srgbRed: 0.00, green: 0.80, blue: 0.84, alpha: 1)
let bgTop = NSColor(srgbRed: 0.03, green: 0.10, blue: 0.11, alpha: 1)
let bgBottom = NSColor.black
let textBright = NSColor(white: 0.97, alpha: 1)
let textDim = NSColor(white: 0.62, alpha: 1)

func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont { .systemFont(ofSize: size, weight: weight) }

// MARK: - 스크린샷 목록 (원본 파일, 큰 문구, 작은 문구)

let shotsKo: [(String, String, String)] = [
    ("01-day", "하루가 한눈에", "24시간 원형 시간표에 한 개비씩 쌓여요"),
    ("02-menu", "꾹 누르면 기록 끝", "누른 자리의 시각으로 바로 추가·삭제"),
    ("03-calendar", "한 달은 달력으로", "이달 하루 평균을 지난달과 비교해요"),
    ("04-calendar-menu", "달력에서도 꾹", "추가, 삭제, 합계에서 빼기까지"),
    ("05-stats", "숫자로 보는 내 습관", "하루 평균, 평균 간격, 자주 피는 시간"),
    ("06-charts", "언제 많이 피는지", "일별·시간대별·요일별로 나눠 봐요"),
    ("07-settings", "계정 없이, 내 기기에", "iCloud 동기화와 CSV 내보내기"),
]

let shotsEn: [(String, String, String)] = [
    ("01-day", "Your day at a glance", "Each one fills a 24-hour clock"),
    ("02-menu", "Press and hold to log", "Add or delete at the time you pressed"),
    ("03-calendar", "Your month by day", "This month's average vs. last month's"),
    ("04-calendar-menu", "Hold any date", "Add, delete or exclude from totals"),
    ("05-stats", "Your habit in numbers", "Daily average, average gap, peak hour"),
    ("06-charts", "When you smoke most", "By day, by hour and by weekday"),
    ("07-settings", "No account needed", "iCloud sync and CSV export"),
]

let languages: [(String, [(String, String, String)])] = [("ko", shotsKo), ("en", shotsEn)]

// MARK: - 그리기 도우미

/// 왼쪽 위가 (0,0)인 좌표로 그린 PNG를 저장한다.
func render(width: Int, height: Int, to url: URL, _ draw: (CGContext) -> Void) {
    // App Store는 알파 채널이 있는 스크린샷을 받지 않으니 처음부터 알파 없는 비트맵에 그린다
    let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    cg.translateBy(x: 0, y: CGFloat(height))
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

/// 한 줄에 다 들어가지 않으면 글자를 조금씩 줄인다(영어 문구가 길 때).
func drawText(_ text: String, font: NSFont, color: NSColor, in rect: CGRect, align: NSTextAlignment = .center, kern: CGFloat = 0) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    style.lineBreakMode = .byTruncatingTail
    var size = font.pointSize
    var attributed: NSAttributedString
    repeat {
        let f = NSFont(descriptor: font.fontDescriptor, size: size) ?? font
        attributed = NSAttributedString(string: text, attributes: [.font: f, .foregroundColor: color, .paragraphStyle: style, .kern: kern * size / font.pointSize])
        size -= 2
    } while attributed.size().width > rect.width && size > font.pointSize * 0.6
    let h = attributed.size().height
    attributed.draw(with: CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h + 4),
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
}

func image(_ url: URL) -> NSImage { NSImage(contentsOf: url)! }

/// 화면 이미지를 둥근 기기 테두리 안에 그린다.
func drawPhone(_ img: NSImage, in rect: CGRect, cg: CGContext, glow: Bool = true) {
    let corner = rect.width * 0.125
    let bezel = rect.width * 0.022
    let outer = rect.insetBy(dx: -bezel, dy: -bezel)
    if glow {
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: rect.width * 0.09, color: teal.withAlphaComponent(0.28).cgColor)
        cg.addPath(CGPath(roundedRect: outer, cornerWidth: corner + bezel, cornerHeight: corner + bezel, transform: nil))
        cg.setFillColor(NSColor(white: 0.10, alpha: 1).cgColor)
        cg.fillPath()
        cg.restoreGState()
    }
    let frame = CGPath(roundedRect: outer, cornerWidth: corner + bezel, cornerHeight: corner + bezel, transform: nil)
    cg.addPath(frame)
    cg.setFillColor(NSColor(white: 0.10, alpha: 1).cgColor)
    cg.fillPath()
    cg.addPath(frame)
    cg.setStrokeColor(NSColor(white: 0.30, alpha: 1).cgColor)
    cg.setLineWidth(max(2, rect.width * 0.003))
    cg.strokePath()
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    cg.clip()
    img.draw(in: rect)
    cg.restoreGState()
}

func drawBackground(_ cg: CGContext, width: CGFloat, height: CGFloat) {
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [bgTop.cgColor, bgBottom.cgColor] as CFArray, locations: [0, 0.55])!
    cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [teal.withAlphaComponent(0.22).cgColor, teal.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    cg.drawRadialGradient(glow, startCenter: CGPoint(x: width / 2, y: height * 0.05), startRadius: 0,
                          endCenter: CGPoint(x: width / 2, y: height * 0.05), endRadius: width * 0.85, options: [])
}

// MARK: - 1) 스크린샷 (6.3형 1206x2622, 6.1형 1179x2556 — App Store Connect가 받는 세로 크기)

let sizes: [(String, Int, Int)] = [("6.3", 1206, 2622), ("6.1", 1179, 2556)]
for (lang, shots) in languages {
let rawDir = here.appendingPathComponent("raw-\(lang)")
for (label, w, h) in sizes {
    let dir = here.appendingPathComponent("\(lang)-\(label)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let W = CGFloat(w), H = CGFloat(h), s = W / 1320
    for (index, shot) in shots.enumerated() {
        let (file, title, subtitle) = shot
        let screen = image(rawDir.appendingPathComponent("\(file).png"))
        render(width: w, height: h, to: dir.appendingPathComponent(String(format: "%02d.png", index + 1))) { cg in
            drawBackground(cg, width: W, height: H)
            drawText(title, font: font(108 * s, .heavy), color: textBright,
                     in: CGRect(x: 60 * s, y: 190 * s, width: W - 120 * s, height: 150 * s), kern: -2 * s)
            drawText(subtitle, font: font(52 * s, .medium), color: textDim,
                     in: CGRect(x: 60 * s, y: 345 * s, width: W - 120 * s, height: 80 * s))
            let phoneW = 1000 * s
            let phoneH = phoneW * 2868 / 1320
            drawPhone(screen, in: CGRect(x: (W - phoneW) / 2, y: H - phoneH - 120 * s, width: phoneW, height: phoneH), cg: cg)
        }
    }
    print("스크린샷 \(lang) \(label)형 \(shots.count)장 → \(dir.path)")
}
}
