// App Store Connect '헤더 및 검색 결과' 크리에이티브 자산을 한국어·영어로 만든다.
// 규격: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
//   제품 페이지 헤더 21:9  3840x1646, 안전 영역 1646x661 (x 1097, y 493)
//   검색 결과        3:2   3840x2560, 안전 영역 2168x1030 (x 836, y 765)
// 단순하게: 무늬 없는 짙은 배경 + 큰 문구 + 원형표(헤더) / 앱 화면(검색 결과).
// 핵심 요소는 안전 영역을 꽉 채우되 밖으로 나가지 않게 한다. 4+ 기준이라 담배 그림은 쓰지 않는다.
// 실행: swift design/appstore/make_creative.swift  (안전 영역 표시본은 --guides)
import AppKit

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outDir = here.appendingPathComponent("creative")
let showGuides = CommandLine.arguments.contains("--guides")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// MARK: - 색

let teal = NSColor(srgbRed: 0.00, green: 0.80, blue: 0.84, alpha: 1)
let bgTop = NSColor(srgbRed: 0.04, green: 0.11, blue: 0.12, alpha: 1)
let bgBottom = NSColor(srgbRed: 0.01, green: 0.03, blue: 0.04, alpha: 1)
let textBright = NSColor(white: 0.97, alpha: 1)
let segmentBase = NSColor(white: 0.16, alpha: 1)
let nowLine = NSColor(srgbRed: 1.0, green: 0.82, blue: 0.0, alpha: 1)

func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont { .systemFont(ofSize: size, weight: weight) }
func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
}

// MARK: - 그리기 도우미

/// 왼쪽 위가 (0,0)인 좌표로 그려 알파 없는 PNG로 저장한다.
func render(width: Int, height: Int, to url: URL, _ draw: (CGContext) -> Void) {
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

/// 무늬 없는 짙은 청록 → 검정 세로 그라데이션
func drawBackground(_ cg: CGContext, size: CGSize) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [bgTop.cgColor, bgBottom.cgColor] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
}

/// 두 줄 문구(흰 줄 + 청록 줄)를 주어진 칸에 들어가는 가장 큰 글자로, 세로 가운데에 그린다.
func drawHeadline(_ lines: (String, String), in rect: CGRect, maxSize: CGFloat) {
    func make(_ s: CGFloat) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = s * 1.22
        style.maximumLineHeight = s * 1.22
        let text = NSMutableAttributedString(string: lines.0 + "\n", attributes: [
            .font: font(s, .heavy), .foregroundColor: textBright, .paragraphStyle: style, .kern: -s * 0.02])
        text.append(NSAttributedString(string: lines.1, attributes: [
            .font: font(s, .heavy), .foregroundColor: teal, .paragraphStyle: style, .kern: -s * 0.02]))
        return text
    }
    var size = maxSize
    var text = make(size)
    while (text.boundingRect(with: CGSize(width: 100_000, height: 100_000), options: [.usesLineFragmentOrigin]).width > rect.width
           || size * 1.22 * 2 > rect.height) && size > 20 {
        size -= 2
        text = make(size)
    }
    let h = size * 1.22 * 2
    text.draw(with: CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h + 10), options: [.usesLineFragmentOrigin])
}

/// 앱의 24시간 원형 시간표(단순화): 0시가 맨 위, 시계 방향. 숫자 라벨 없이 칸·점·지금 선·가운데 합계만.
func drawClock(_ cg: CGContext, center: CGPoint, radius R: CGFloat, dots: [Double], now: Double, total: Int) {
    let inner = R * 0.56
    func angle(_ hour: Double) -> CGFloat { -CGFloat.pi / 2 + CGFloat(hour / 24) * 2 * .pi }
    func point(_ radius: CGFloat, _ hour: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle(hour)), y: center.y + radius * sin(angle(hour)))
    }
    let filled = Set(dots.map { Int($0) })
    for h in 0..<24 {
        let path = CGMutablePath()
        path.addArc(center: center, radius: R, startAngle: angle(Double(h)), endAngle: angle(Double(h + 1)), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: angle(Double(h + 1)), endAngle: angle(Double(h)), clockwise: true)
        path.closeSubpath()
        cg.addPath(path)
        cg.setFillColor((filled.contains(h) ? teal : segmentBase).cgColor)
        cg.fillPath()
        cg.addPath(path)
        cg.setStrokeColor(bgBottom.cgColor)
        cg.setLineWidth(R * 0.016)
        cg.strokePath()
    }
    // 지금 시각 노란 선
    cg.move(to: point(inner - R * 0.03, now))
    cg.addLine(to: point(R + R * 0.03, now))
    cg.setStrokeColor(nowLine.cgColor)
    cg.setLineWidth(R * 0.03)
    cg.setLineCap(.round)
    cg.strokePath()
    // 기록 점
    let dotR = R * 0.045
    for d in dots {
        let p = point((R + inner) / 2 + R * 0.06, d)
        let rect = CGRect(x: p.x - dotR, y: p.y - dotR, width: 2 * dotR, height: 2 * dotR)
        cg.addEllipse(in: rect)
        cg.setFillColor(teal.cgColor)
        cg.fillPath()
        cg.addEllipse(in: rect)
        cg.setStrokeColor(NSColor(white: 0.06, alpha: 1).cgColor)
        cg.setLineWidth(R * 0.014)
        cg.strokePath()
    }
    // 가운데 합계
    let number = NSAttributedString(string: "\(total)", attributes: [.font: rounded(R * 0.46, .bold), .foregroundColor: textBright])
    let size = number.size()
    number.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
}

/// 화면 이미지를 둥근 기기 테두리 안에 그린다.
func drawPhone(_ img: NSImage, in rect: CGRect, cg: CGContext) {
    let corner = rect.width * 0.125
    let bezel = rect.width * 0.022
    let outer = rect.insetBy(dx: -bezel, dy: -bezel)
    let frame = CGPath(roundedRect: outer, cornerWidth: corner + bezel, cornerHeight: corner + bezel, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: rect.width * 0.04), blur: rect.width * 0.10, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    cg.addPath(frame)
    cg.setFillColor(NSColor(white: 0.10, alpha: 1).cgColor)
    cg.fillPath()
    cg.restoreGState()
    cg.addPath(frame)
    cg.setStrokeColor(NSColor(white: 0.30, alpha: 1).cgColor)
    cg.setLineWidth(max(2, rect.width * 0.004))
    cg.strokePath()
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    cg.clip()
    img.draw(in: rect)
    cg.restoreGState()
}

/// 확인용: 안전 영역을 빨간 점선으로
func drawGuide(_ cg: CGContext, _ rect: CGRect) {
    guard showGuides else { return }
    cg.setStrokeColor(NSColor.systemRed.cgColor)
    cg.setLineWidth(6)
    cg.setLineDash(phase: 0, lengths: [30, 20])
    cg.stroke(rect)
    cg.setLineDash(phase: 0, lengths: [])
}

// MARK: - 언어별 문구

struct Copy {
    let lang: String
    let headline: (String, String)   // (흰 줄, 청록 줄)
}
let copies = [
    Copy(lang: "ko", headline: ("흡연 기록을 손쉽게,", "스스로 줄여나가요.")),
    Copy(lang: "en", headline: ("Easy smoking log,", "cut down on your own.")),
]

// 예시 하루: 7개비, 지금은 저녁 9시 20분
let dayDots: [Double] = [7.7, 8.45, 10.35, 13.1, 15.8, 18.65, 20.57]
let dayNow = 21.33
let suffix = showGuides ? "-guides" : ""

for copy in copies {
    let rawDir = here.appendingPathComponent("raw-\(copy.lang)")

    // MARK: 제품 페이지 헤더 3840x1646 — 왼쪽 문구, 오른쪽 원형표. 안전 영역 높이를 꽉 채운다.
    do {
        let W: CGFloat = 3840, H: CGFloat = 1646
        let safe = CGRect(x: 1097, y: 493, width: 1646, height: 661)
        let clockR = safe.height * 0.42
        let clockCenter = CGPoint(x: safe.maxX - clockR - 6, y: safe.midY)
        let url = outDir.appendingPathComponent("header-\(copy.lang)\(suffix).png")
        render(width: Int(W), height: Int(H), to: url) { cg in
            drawBackground(cg, size: CGSize(width: W, height: H))
            let textRect = CGRect(x: safe.minX, y: safe.minY, width: clockCenter.x - clockR - safe.minX - 80, height: safe.height)
            drawHeadline(copy.headline, in: textRect, maxSize: 150)
            drawClock(cg, center: clockCenter, radius: clockR, dots: dayDots, now: dayNow, total: dayDots.count)
            drawGuide(cg, safe)
        }
        print("헤더 → \(url.path)")
    }

    // MARK: 검색 결과 3840x2560 — 왼쪽 문구, 오른쪽 앱 화면 한 장
    do {
        let W: CGFloat = 3840, H: CGFloat = 2560
        let safe = CGRect(x: 836, y: 765, width: 2168, height: 1030)
        let day = NSImage(contentsOf: rawDir.appendingPathComponent("01-day.png"))!
        let url = outDir.appendingPathComponent("search-\(copy.lang)\(suffix).png")
        render(width: Int(W), height: Int(H), to: url) { cg in
            drawBackground(cg, size: CGSize(width: W, height: H))
            // 화면 위쪽(원형표·달력)은 안전 영역 안, 아래쪽 목록은 안전 영역 밖으로 흘러내려도 된다
            let phoneH: CGFloat = 1500
            let phoneW = phoneH * 1320 / 2868
            let front = CGRect(x: safe.maxX - phoneW - 16, y: safe.minY + 24, width: phoneW, height: phoneH)
            drawPhone(day, in: front, cg: cg)
            let textRect = CGRect(x: safe.minX, y: safe.minY, width: front.minX - safe.minX - 110, height: safe.height)
            drawHeadline(copy.headline, in: textRect, maxSize: 180)
            drawGuide(cg, safe)
        }
        print("검색 결과 → \(url.path)")
    }
}
