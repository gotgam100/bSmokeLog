// 원형 시간표 디자인 시안 3가지 (네모 카드 배경 없음). 720x720 PNG + 비교 시트.
// 실행: swift design/clock/make_clocks.swift <출력 폴더>
import AppKit
import CoreGraphics

let size: CGFloat = 720
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let bg = NSColor.black                                                   // 앱의 다크 배경
let teal = NSColor(srgbRed: 0.00, green: 0.78, blue: 0.80, alpha: 1)      // 연초
let purple = NSColor(srgbRed: 0.80, green: 0.30, blue: 0.90, alpha: 1)    // 전자담배
let green = NSColor(srgbRed: 0.30, green: 0.80, blue: 0.45, alpha: 1)     // 니코틴껌
let yellow = NSColor(srgbRed: 1.0, green: 0.84, blue: 0.0, alpha: 1)      // 지금 시각
let track = NSColor(white: 0.17, alpha: 1)
let textDim = NSColor(white: 0.55, alpha: 1)
let textBright = NSColor(white: 0.95, alpha: 1)

/// 시간(시 단위)과 종류 색. 하루치 예시.
let sample: [(Double, NSColor)] = [
    (0.7, teal), (8.3, teal), (9.1, teal), (10.6, purple), (12.6, teal), (13.1, green),
    (13.4, teal), (15.2, purple), (17.9, teal), (18.4, teal), (19.6, purple), (21.7, teal), (23.1, green),
]
let nowHour = 22.3
let center = CGPoint(x: size / 2, y: size / 2)

func rad(_ hour: Double) -> CGFloat { CGFloat(hour * 15 - 90) * .pi / 180 }
func pt(_ r: CGFloat, _ hour: Double) -> CGPoint { CGPoint(x: center.x + r * cos(rad(hour)), y: center.y + r * sin(rad(hour))) }

func image(_ draw: (CGContext) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocusFlipped(true)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(bg.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    draw(ctx)
    img.unlockFocus()
    return img
}

func text(_ s: String, size fs: CGFloat, weight: NSFont.Weight, color: NSColor, at p: CGPoint, rounded: Bool = false) {
    var font = NSFont.systemFont(ofSize: fs, weight: weight)
    if rounded, let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: fs) { font = f }
    let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
    let b = str.size()
    str.draw(at: CGPoint(x: p.x - b.width / 2, y: p.y - b.height / 2))
}

func arc(_ ctx: CGContext, r: CGFloat, from a: Double, to b: Double, width: CGFloat, color: NSColor, cap: CGLineCap = .butt) {
    ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(width); ctx.setLineCap(cap)
    ctx.addArc(center: center, radius: r, startAngle: rad(a), endAngle: rad(b), clockwise: false)
    ctx.strokePath()
}

func dot(_ ctx: CGContext, at p: CGPoint, r: CGFloat, color: NSColor, glow: Bool = false) {
    if glow {
        ctx.setFillColor(color.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - r * 2.2, y: p.y - r * 2.2, width: r * 4.4, height: r * 4.4))
    }
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    ctx.setStrokeColor(bg.cgColor); ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}

func hourLabels(r: CGFloat, majorOnly: Bool) {
    for h in 0..<24 {
        let major = h % 6 == 0
        if majorOnly && !major { continue }
        text("\(h)", size: major ? 22 : 15, weight: major ? .bold : .regular, color: major ? textBright : textDim, at: pt(r, Double(h)))
    }
}

func centerCount(_ n: Int, size fs: CGFloat = 64) {
    text("\(n)", size: fs, weight: .bold, color: textBright, at: CGPoint(x: center.x, y: center.y - 8), rounded: true)
    text("개비", size: 18, weight: .regular, color: textDim, at: CGPoint(x: center.x, y: center.y + fs * 0.62))
}

/// 시간대별 개수와 대표색
func hourly() -> [(count: Int, color: NSColor)] {
    var out = Array(repeating: (count: 0, color: teal), count: 24)
    for (h, c) in sample { let i = Int(h); out[i].count += 1; out[i].color = c }
    return out
}

// A. 얇은 고리: 가는 회색 트랙 위에 피운 시간대만 색 띠, 점은 띠 위에. 부채꼴 없음.
let ringA = image { ctx in
    let r: CGFloat = 250
    arc(ctx, r: r, from: 0, to: 24, width: 16, color: track)
    for (h, item) in hourly().enumerated() where item.count > 0 {
        arc(ctx, r: r, from: Double(h) + 0.06, to: Double(h) + 0.94, width: 16,
            color: item.color.withAlphaComponent(0.45 + 0.25 * CGFloat(min(item.count, 3))), cap: .round)
    }
    for (h, c) in sample { dot(ctx, at: pt(r, h), r: 7, color: c) }
    // 지금 시각: 고리 바깥 짧은 노란 선
    ctx.setStrokeColor(yellow.cgColor); ctx.setLineWidth(4); ctx.setLineCap(.round)
    ctx.move(to: pt(r + 16, nowHour)); ctx.addLine(to: pt(r + 36, nowHour)); ctx.strokePath()
    hourLabels(r: r - 46, majorOnly: false)
    centerCount(sample.count)
}

// B. 글로우 점: 고리도 칸도 없이, 24개의 작은 눈금과 빛나는 점. 첫 기록부터 마지막까지 희미한 호.
let glowB = image { ctx in
    let r: CGFloat = 250
    for h in 0..<24 {
        let major = h % 6 == 0
        ctx.setStrokeColor((major ? textDim : track).cgColor); ctx.setLineWidth(major ? 3 : 2); ctx.setLineCap(.round)
        ctx.move(to: pt(r - (major ? 14 : 8), Double(h))); ctx.addLine(to: pt(r + (major ? 14 : 8), Double(h))); ctx.strokePath()
    }
    if let first = sample.map(\.0).min(), let last = sample.map(\.0).max() {
        arc(ctx, r: r, from: first, to: last, width: 3, color: teal.withAlphaComponent(0.25), cap: .round)
    }
    for (h, c) in sample { dot(ctx, at: pt(r, h), r: 9, color: c, glow: true) }
    ctx.setStrokeColor(yellow.cgColor); ctx.setLineWidth(3); ctx.setLineCap(.round)
    ctx.move(to: pt(r - 40, nowHour)); ctx.addLine(to: pt(r - 18, nowHour)); ctx.strokePath()
    hourLabels(r: r + 44, majorOnly: true)
    centerCount(sample.count, size: 80)
}

// C. 두꺼운 히트맵 도넛: 24칸을 칸마다 개수에 따라 진하게. 중심에서 뻗는 부채꼴 대신 고리 모양.
let donutC = image { ctx in
    let r: CGFloat = 230, w: CGFloat = 78
    for (h, item) in hourly().enumerated() {
        let color = item.count == 0 ? track : item.color.withAlphaComponent(0.35 + 0.22 * CGFloat(min(item.count, 3)))
        arc(ctx, r: r, from: Double(h) + 0.035, to: Double(h) + 0.965, width: w, color: color)
    }
    for (h, c) in sample { dot(ctx, at: pt(r + w / 2 - 12, h), r: 6, color: c) }
    // 지금 시각: 도넛을 가로지르는 노란 선
    ctx.setStrokeColor(yellow.cgColor); ctx.setLineWidth(4); ctx.setLineCap(.round)
    ctx.move(to: pt(r - w / 2 - 4, nowHour)); ctx.addLine(to: pt(r + w / 2 + 4, nowHour)); ctx.strokePath()
    hourLabels(r: r + w / 2 + 30, majorOnly: false)
    centerCount(sample.count)
}

let candidates: [(String, String, NSImage)] = [
    ("A", "얇은 고리", ringA),
    ("B", "글로우 점", glowB),
    ("C", "히트맵 도넛", donutC),
]

func savePNG(_ img: NSImage, _ path: String) {
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for (n, _, img) in candidates { savePNG(img, "\(outDir)/clock-\(n).png") }

// 비교 시트: 아이폰 화면처럼 검은 바탕에 가로로 셋
let cell: CGFloat = 360, pad: CGFloat = 40, label: CGFloat = 60
let sheetW = pad + 3 * (cell + pad), sheetH = pad + cell + label + pad
let sheet = NSImage(size: NSSize(width: sheetW, height: sheetH))
sheet.lockFocusFlipped(true)
bg.setFill(); NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()
for (i, (n, name, img)) in candidates.enumerated() {
    let r = NSRect(x: pad + CGFloat(i) * (cell + pad), y: pad, width: cell, height: cell)
    img.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    let s = NSAttributedString(string: "\(n). \(name)", attributes: [.font: NSFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: textBright])
    s.draw(at: CGPoint(x: r.midX - s.size().width / 2, y: r.maxY + 14))
}
sheet.unlockFocus()
savePNG(sheet, "\(outDir)/clock-candidates.png")
print("ok")
