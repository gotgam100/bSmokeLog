// 앱 아이콘 후보를 1024x1024 PNG로 그리고, 한 장짜리 비교 시트를 만든다.
// 실행: swift design/icons/make_icons.swift <출력 폴더>
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// 앱의 청록(brand) 계열
let teal = NSColor(srgbRed: 0.00, green: 0.72, blue: 0.76, alpha: 1)
let tealDeep = NSColor(srgbRed: 0.00, green: 0.50, blue: 0.56, alpha: 1)
let tealSoft = NSColor(srgbRed: 0.66, green: 0.90, blue: 0.91, alpha: 1)
let ink = NSColor(srgbRed: 0.11, green: 0.13, blue: 0.15, alpha: 1)
let paper = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1)
let purple = NSColor(srgbRed: 0.78, green: 0.30, blue: 0.88, alpha: 1)

func image(_ draw: (CGContext) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocusFlipped(true)
    let ctx = NSGraphicsContext.current!.cgContext
    draw(ctx)
    img.unlockFocus()
    return img
}

func fill(_ ctx: CGContext, _ color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

func gradient(_ ctx: CGContext, _ top: NSColor, _ bottom: NSColor) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size), options: [])
}

func text(_ s: String, size fs: CGFloat, weight: NSFont.Weight, color: NSColor, center: CGPoint, rounded: Bool = true) {
    var font = NSFont.systemFont(ofSize: fs, weight: weight)
    if rounded, let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: fs) { font = f }
    let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: s, attributes: attr)
    let b = str.size()
    str.draw(at: CGPoint(x: center.x - b.width / 2, y: center.y - b.height / 2))
}

func wedge(_ ctx: CGContext, center c: CGPoint, r: CGFloat, hour: Int) {
    let a0 = CGFloat(hour) * 15 - 90, a1 = a0 + 15
    ctx.move(to: c)
    ctx.addArc(center: c, radius: r, startAngle: a0 * .pi / 180, endAngle: a1 * .pi / 180, clockwise: false)
    ctx.closePath()
}

// 1. 원형 시간표: 앱의 24시간 원을 그대로 단순화
let clock = image { ctx in
    fill(ctx, paper)
    let c = CGPoint(x: size / 2, y: size / 2), r: CGFloat = 360
    ctx.setFillColor(NSColor(white: 0.88, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    for (h, col) in [(9, tealSoft), (10, teal), (13, tealSoft), (18, teal), (19, tealDeep), (21, tealSoft)] {
        wedge(ctx, center: c, r: r, hour: h)
        ctx.setFillColor(col.cgColor); ctx.fillPath()
    }
    ctx.setStrokeColor(paper.cgColor); ctx.setLineWidth(10)
    for h in 0..<24 {
        let a = (CGFloat(h) * 15 - 90) * .pi / 180
        ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
    }
    ctx.strokePath()
    ctx.setFillColor(paper.cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - 140, y: c.y - 140, width: 280, height: 280))
}

// 2. 달력 한 칸: 날짜 위, 개수 동그라미 아래 (앱 달력 칸 그대로)
let dayCell = image { ctx in
    gradient(ctx, teal, tealDeep)
    let card = CGRect(x: 212, y: 200, width: 600, height: 640)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 110, cornerHeight: 110, transform: nil))
    ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
    text("14", size: 150, weight: .semibold, color: NSColor(white: 0.55, alpha: 1), center: CGPoint(x: 512, y: 330))
    ctx.setFillColor(tealSoft.cgColor)
    ctx.fillEllipse(in: CGRect(x: 352, y: 450, width: 320, height: 320))
    ctx.setStrokeColor(teal.cgColor); ctx.setLineWidth(22)
    ctx.strokeEllipse(in: CGRect(x: 363, y: 461, width: 298, height: 298))
    text("3", size: 210, weight: .bold, color: ink, center: CGPoint(x: 512, y: 612))
}

// 3. 카운터 +1: 기록 한 번이 전부라는 느낌
let plusOne = image { ctx in
    fill(ctx, ink)
    ctx.setStrokeColor(teal.cgColor); ctx.setLineWidth(46)
    ctx.strokeEllipse(in: CGRect(x: 202, y: 202, width: 620, height: 620))
    text("+1", size: 330, weight: .heavy, color: .white, center: CGPoint(x: 505, y: 512))
}

// 4. 연기 한 줄: 흰 바탕의 청록 곡선 하나
let smoke = image { ctx in
    fill(ctx, paper)
    ctx.setStrokeColor(teal.cgColor); ctx.setLineWidth(70); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 512, y: 830))
    ctx.addCurve(to: CGPoint(x: 512, y: 520), control1: CGPoint(x: 330, y: 730), control2: CGPoint(x: 700, y: 620))
    ctx.addCurve(to: CGPoint(x: 520, y: 200), control1: CGPoint(x: 330, y: 420), control2: CGPoint(x: 700, y: 300))
    ctx.strokePath()
}

// 5. B + 연기: 앱 이름 첫 글자, 위로 가는 짧은 연기
let letterB = image { ctx in
    gradient(ctx, teal, tealDeep)
    text("B", size: 600, weight: .black, color: .white, center: CGPoint(x: 460, y: 580))
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor); ctx.setLineWidth(34); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 720, y: 400))
    ctx.addCurve(to: CGPoint(x: 740, y: 200), control1: CGPoint(x: 650, y: 330), control2: CGPoint(x: 810, y: 270))
    ctx.strokePath()
}

// 6. 바 차트 세 개: 통계를 한눈에
let bars = image { ctx in
    fill(ctx, .white)
    for (i, (h, col)) in [(300.0, tealSoft), (460.0, teal), (380.0, purple)].enumerated() {
        let x = 262 + CGFloat(i) * 180
        let r = CGRect(x: x, y: 790 - h, width: 140, height: h)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 40, cornerHeight: 40, transform: nil))
        ctx.setFillColor(col.cgColor); ctx.fillPath()
    }
}

let candidates: [(String, String, NSImage)] = [
    ("1", "원형 시간표", clock),
    ("2", "달력 한 칸", dayCell),
    ("3", "+1 카운터", plusOne),
    ("4", "연기 한 줄", smoke),
    ("5", "B + 연기", letterB),
    ("6", "막대 세 개", bars),
]

func savePNG(_ img: NSImage, _ path: String) {
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for (n, _, img) in candidates { savePNG(img, "\(outDir)/icon-\(n).png") }

// 비교 시트: 아이폰 아이콘 모양(둥근 모서리)으로 3x2 배치 + 이름
let cell: CGFloat = 300, pad: CGFloat = 60, label: CGFloat = 70
let sheetW = pad + 3 * (cell + pad), sheetH = pad + 2 * (cell + label + pad)
let sheet = NSImage(size: NSSize(width: sheetW, height: sheetH))
sheet.lockFocusFlipped(true)
NSColor(white: 0.93, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()
for (i, (n, name, img)) in candidates.enumerated() {
    let col = CGFloat(i % 3), row = CGFloat(i / 3)
    let r = NSRect(x: pad + col * (cell + pad), y: pad + row * (cell + label + pad), width: cell, height: cell)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: cell * 0.225, yRadius: cell * 0.225).addClip()
    img.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    let attr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 34, weight: .semibold), .foregroundColor: ink]
    let s = NSAttributedString(string: "\(n). \(name)", attributes: attr)
    s.draw(at: CGPoint(x: r.midX - s.size().width / 2, y: r.maxY + 14))
}
sheet.unlockFocus()
savePNG(sheet, "\(outDir)/icon-candidates.png")
print("ok")
