// 앱스토어 스크린샷(문구 + 기기 화면)과 헤더·검색 결과 미리보기를 만든다.
// 원본은 raw-ko/ 에 있는 시뮬레이터 캡처(1320x2868, 실행 인자 -screenshotData).
// 실행: swift design/appstore/make_screenshots.swift
import AppKit

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let root = here.deletingLastPathComponent().deletingLastPathComponent()
let rawDir = here.appendingPathComponent("raw-ko")
let iconURL = root.appendingPathComponent("SmokeLog/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

// MARK: - 색과 글꼴

let teal = NSColor(srgbRed: 0.00, green: 0.80, blue: 0.84, alpha: 1)
let bgTop = NSColor(srgbRed: 0.03, green: 0.10, blue: 0.11, alpha: 1)
let bgBottom = NSColor.black
let textBright = NSColor(white: 0.97, alpha: 1)
let textDim = NSColor(white: 0.62, alpha: 1)

func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont { .systemFont(ofSize: size, weight: weight) }

// MARK: - 스크린샷 목록 (원본 파일, 큰 문구, 작은 문구)

let shots: [(String, String, String)] = [
    ("01-day", "하루가 한눈에", "24시간 원형 시간표에 한 개비씩 쌓여요"),
    ("02-menu", "꾹 누르면 기록 끝", "누른 자리의 시각으로 바로 추가·삭제"),
    ("03-calendar", "한 달은 달력으로", "이달 하루 평균을 지난달과 비교해요"),
    ("04-calendar-menu", "달력에서도 꾹", "추가, 삭제, 합계에서 빼기까지"),
    ("05-stats", "숫자로 보는 내 습관", "하루 평균, 평균 간격, 자주 피는 시간"),
    ("06-charts", "언제 많이 피는지", "일별·시간대별·요일별로 나눠 봐요"),
    ("07-settings", "계정 없이, 내 기기에", "iCloud 동기화와 CSV 내보내기"),
]

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

func drawText(_ text: String, font: NSFont, color: NSColor, in rect: CGRect, align: NSTextAlignment = .center, kern: CGFloat = 0) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    style.lineBreakMode = .byTruncatingTail
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style, .kern: kern])
        .draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
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

// MARK: - 1) 스크린샷 (6.9형 1320x2868, 6.5형 1284x2778)

let sizes: [(String, Int, Int)] = [("6.9", 1320, 2868), ("6.5", 1284, 2778)]
for (label, w, h) in sizes {
    let dir = here.appendingPathComponent("ko-\(label)")
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
    print("스크린샷 \(label)형 \(shots.count)장 → \(dir.path)")
}

// MARK: - 2) 미리보기: 앱스토어 검색 결과 / 제품 페이지 헤더 (다크 모드 기준 모형)

let icon = image(iconURL)
let finals = (1...shots.count).map { image(here.appendingPathComponent(String(format: "ko-6.9/%02d.png", $0))) }
let name = "B흡연로그 - 담배 기록"
let subtitle = "꾹 눌러 기록, 원형 시간표로 한눈에"
let pageBG = NSColor.black
let cardBG = NSColor(white: 0.11, alpha: 1)
let blue = NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1)

func drawIcon(_ rect: CGRect, cg: CGContext) {
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil))
    cg.clip()
    icon.draw(in: rect)
    cg.restoreGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil))
    cg.setStrokeColor(NSColor(white: 1, alpha: 0.12).cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
}

func getButton(_ center: CGPoint, scale: CGFloat, cg: CGContext) {
    let rect = CGRect(x: center.x - 110 * scale, y: center.y - 42 * scale, width: 220 * scale, height: 84 * scale)
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil))
    cg.setFillColor(NSColor(white: 0.22, alpha: 1).cgColor)
    cg.fillPath()
    drawText("받기", font: font(40 * scale, .bold), color: blue, in: rect.offsetBy(dx: 0, dy: 16 * scale))
}

func roundedImage(_ img: NSImage, in rect: CGRect, radius: CGFloat, cg: CGContext) {
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    cg.clip()
    img.draw(in: rect)
    cg.restoreGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    cg.setStrokeColor(NSColor(white: 1, alpha: 0.10).cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
}

// 검색 결과: 아이콘·이름·부제·받기 + 첫 3장
let previewDir = here.appendingPathComponent("preview")
try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
render(width: 1320, height: 1390, to: previewDir.appendingPathComponent("search-result.png")) { cg in
    cg.setFillColor(pageBG.cgColor); cg.fill(CGRect(x: 0, y: 0, width: 1320, height: 1390))
    // 검색창
    let bar = CGRect(x: 48, y: 60, width: 1224, height: 110)
    cg.addPath(CGPath(roundedRect: bar, cornerWidth: 32, cornerHeight: 32, transform: nil))
    cg.setFillColor(cardBG.cgColor); cg.fillPath()
    drawText("􀊫  흡연 기록", font: font(46, .regular), color: textDim, in: bar.insetBy(dx: 36, dy: 28), align: .left)
    // 앱 줄
    drawIcon(CGRect(x: 48, y: 230, width: 190, height: 190), cg: cg)
    drawText(name, font: font(48, .semibold), color: textBright, in: CGRect(x: 272, y: 252, width: 760, height: 64), align: .left)
    drawText(subtitle, font: font(40, .regular), color: textDim, in: CGRect(x: 272, y: 322, width: 760, height: 56), align: .left)
    drawText("건강 및 피트니스", font: font(34, .regular), color: textDim.withAlphaComponent(0.7), in: CGRect(x: 272, y: 376, width: 760, height: 50), align: .left)
    getButton(CGPoint(x: 1162, y: 325), scale: 1, cg: cg)
    // 스크린샷 3장
    let gap: CGFloat = 24
    let w = (1224 - gap * 2) / 3
    let h = w * 2868 / 1320
    for i in 0..<3 {
        roundedImage(finals[i], in: CGRect(x: 48 + CGFloat(i) * (w + gap), y: 470, width: w, height: h), radius: 34, cg: cg)
    }
}
print("검색 결과 미리보기 → \(previewDir.appendingPathComponent("search-result.png").path)")

// 제품 페이지 헤더: 큰 아이콘·이름·부제·받기 + 정보 줄 + 스크린샷 가로 목록
render(width: 1320, height: 2620, to: previewDir.appendingPathComponent("product-header.png")) { cg in
    cg.setFillColor(pageBG.cgColor); cg.fill(CGRect(x: 0, y: 0, width: 1320, height: 2620))
    drawText("􀆉 검색", font: font(46, .regular), color: blue, in: CGRect(x: 40, y: 70, width: 400, height: 64), align: .left)
    drawIcon(CGRect(x: 48, y: 170, width: 380, height: 380), cg: cg)
    drawText(name, font: font(64, .bold), color: textBright, in: CGRect(x: 470, y: 190, width: 810, height: 170), align: .left)
    drawText(subtitle, font: font(44, .regular), color: textDim, in: CGRect(x: 470, y: 290, width: 810, height: 64), align: .left)
    let get = CGRect(x: 470, y: 450, width: 230, height: 84)
    cg.addPath(CGPath(roundedRect: get, cornerWidth: 42, cornerHeight: 42, transform: nil))
    cg.setFillColor(blue.cgColor); cg.fillPath()
    drawText("받기", font: font(42, .bold), color: .white, in: get.offsetBy(dx: 0, dy: 15))
    drawText("􀈂", font: font(52, .regular), color: blue, in: CGRect(x: 1180, y: 455, width: 90, height: 80))
    // 정보 줄
    let line = CGRect(x: 48, y: 610, width: 1224, height: 2)
    cg.setFillColor(NSColor(white: 0.22, alpha: 1).cgColor); cg.fill(line)
    let infos: [(String, String, String)] = [
        ("평가", "신규", "평가 없음"), ("연령", "17+", "세"), ("카테고리", "􀊵", "건강 및 피트니스"),
        ("개발자", "􀉪", "bSmokeLog"), ("언어", "KO", "+ 1개"),
    ]
    let colW: CGFloat = 1224 / 5
    for (i, info) in infos.enumerated() {
        let x = 48 + CGFloat(i) * colW
        drawText(info.0, font: font(30, .semibold), color: textDim.withAlphaComponent(0.8), in: CGRect(x: x, y: 650, width: colW, height: 44))
        drawText(info.1, font: font(52, .bold), color: textDim, in: CGRect(x: x, y: 700, width: colW, height: 72))
        drawText(info.2, font: font(30, .regular), color: textDim.withAlphaComponent(0.8), in: CGRect(x: x, y: 780, width: colW, height: 44))
        if i > 0 { cg.setFillColor(NSColor(white: 0.22, alpha: 1).cgColor); cg.fill(CGRect(x: x, y: 660, width: 2, height: 150)) }
    }
    cg.setFillColor(NSColor(white: 0.22, alpha: 1).cgColor); cg.fill(CGRect(x: 48, y: 860, width: 1224, height: 2))
    // 미리보기 (가로로 넘기는 스크린샷, 1.5장이 보이게)
    drawText("미리보기", font: font(56, .bold), color: textBright, in: CGRect(x: 48, y: 900, width: 600, height: 80), align: .left)
    let w: CGFloat = 690, h = w * 2868 / 1320
    for i in 0..<2 {
        roundedImage(finals[i], in: CGRect(x: 48 + CGFloat(i) * (w + 30), y: 1000, width: w, height: h), radius: 54, cg: cg)
    }
    drawText("􀟜  iPhone", font: font(34, .regular), color: textDim, in: CGRect(x: 48, y: 2535, width: 600, height: 50), align: .left)
}
print("제품 페이지 헤더 미리보기 → \(previewDir.appendingPathComponent("product-header.png").path)")
