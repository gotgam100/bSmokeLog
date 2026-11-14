// 부러진 담배·꺼진 담배 변주 (v3). 1024x1024 PNG + 비교 시트.
// 실행: swift design/icons/make_icons_v3.swift <출력 폴더>
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let teal = NSColor(srgbRed: 0.00, green: 0.72, blue: 0.76, alpha: 1)
let tealDeep = NSColor(srgbRed: 0.00, green: 0.50, blue: 0.56, alpha: 1)
let tealSoft = NSColor(srgbRed: 0.80, green: 0.95, blue: 0.95, alpha: 1)
let ink = NSColor(srgbRed: 0.13, green: 0.15, blue: 0.17, alpha: 1)
let paper = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1)
let filter = NSColor(srgbRed: 0.93, green: 0.62, blue: 0.33, alpha: 1)   // 담배 필터(주황 갈색)
let ash = NSColor(srgbRed: 0.62, green: 0.64, blue: 0.66, alpha: 1)
let ember = NSColor(srgbRed: 0.96, green: 0.40, blue: 0.27, alpha: 1)
let leaf = NSColor(srgbRed: 0.30, green: 0.75, blue: 0.45, alpha: 1)
let slash = NSColor(srgbRed: 0.90, green: 0.30, blue: 0.30, alpha: 1)

func image(_ draw: (CGContext) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocusFlipped(true)
    draw(NSGraphicsContext.current!.cgContext)
    img.unlockFocus()
    return img
}

func fill(_ ctx: CGContext, _ c: NSColor) {
    ctx.setFillColor(c.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

func gradient(_ ctx: CGContext, _ top: NSColor, _ bottom: NSColor) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size), options: [])
}

func rounded(_ ctx: CGContext, _ r: CGRect, _ radius: CGFloat, _ c: NSColor) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(c.cgColor); ctx.fillPath()
}

/// 가로 담배: 왼쪽 필터 + 흰 몸통 + (선택) 오른쪽 불씨. 중심·길이·각도 지정.
func cigarette(_ ctx: CGContext, center: CGPoint, length: CGFloat, thickness t: CGFloat,
               angle: CGFloat, filterRatio: CGFloat = 0.3, tip: NSColor? = nil, body: NSColor = .white) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle * .pi / 180)
    let x0 = -length / 2
    let r = t * 0.22
    // 몸통 전체(둥근 사각) 클립
    let whole = CGRect(x: x0, y: -t / 2, width: length, height: t)
    ctx.addPath(CGPath(roundedRect: whole, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.clip()
    ctx.setFillColor(body.cgColor); ctx.fill(whole)
    ctx.setFillColor(filter.cgColor)
    ctx.fill(CGRect(x: x0, y: -t / 2, width: length * filterRatio, height: t))
    if let tip {
        ctx.setFillColor(tip.cgColor)
        ctx.fill(CGRect(x: x0 + length - t * 0.55, y: -t / 2, width: t * 0.55, height: t))
    }
    ctx.restoreGState()
}

func line(_ ctx: CGContext, _ pts: [CGPoint], width: CGFloat, color: NSColor) {
    ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(width); ctx.setLineCap(.round)
    ctx.move(to: pts[0]); for p in pts.dropFirst() { ctx.addLine(to: p) }
    ctx.strokePath()
}

/// 잎 하나 (두 곡선으로 만든 물방울 모양)
func leafShape(_ ctx: CGContext, base: CGPoint, tip: CGPoint, width w: CGFloat, color: NSColor) {
    let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
    let dx = tip.x - base.x, dy = tip.y - base.y
    let len = sqrt(dx * dx + dy * dy)
    let nx = -dy / len * w, ny = dx / len * w
    ctx.move(to: base)
    ctx.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
    ctx.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
    ctx.setFillColor(color.cgColor); ctx.fillPath()
}


/// 꺾인 꽁초: 필터+몸통 뒤에 짧게 꺾인 끝(비벼 끈 모양)과 재 끝
func crushedButt(_ ctx: CGContext, center: CGPoint, length: CGFloat, thickness t: CGFloat, angle: CGFloat, bend: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle * .pi / 180)
    // 곧은 부분 (필터 + 짧은 몸통)
    cigarette(ctx, center: CGPoint(x: -length * 0.15, y: 0), length: length * 0.7, thickness: t, angle: 0, filterRatio: 0.55)
    // 꺾인 끝 (구겨져 짧아진 부분, 끝은 회색 재)
    let joint = CGPoint(x: length * 0.2 - t * 0.1, y: 0)
    ctx.translateBy(x: joint.x, y: joint.y)
    ctx.rotate(by: bend * .pi / 180)
    let seg = CGRect(x: 0, y: -t / 2 * 0.9, width: length * 0.3, height: t * 0.9)
    ctx.addPath(CGPath(roundedRect: seg, cornerWidth: t * 0.2, cornerHeight: t * 0.2, transform: nil))
    ctx.clip()
    ctx.setFillColor(NSColor(white: 0.93, alpha: 1).cgColor); ctx.fill(seg)
    ctx.setFillColor(NSColor(white: 0.45, alpha: 1).cgColor)
    ctx.fill(CGRect(x: seg.maxX - t * 0.45, y: seg.minY, width: t * 0.45, height: seg.height))
    ctx.restoreGState()
}

/// 동그란 체크 배지
func checkBadge(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, fillColor: NSColor, checkColor: NSColor) {
    ctx.setFillColor(fillColor.cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    line(ctx, [CGPoint(x: c.x - r * 0.42, y: c.y + r * 0.02),
               CGPoint(x: c.x - r * 0.1, y: c.y + r * 0.34),
               CGPoint(x: c.x + r * 0.45, y: c.y - r * 0.32)], width: r * 0.2, color: checkColor)
}

// C1. 진한 청록 바탕 + 흰 부러진 담배
let c1 = image { ctx in
    gradient(ctx, teal, tealDeep)
    cigarette(ctx, center: CGPoint(x: 330, y: 640), length: 430, thickness: 140, angle: -20, filterRatio: 0.45)
    cigarette(ctx, center: CGPoint(x: 725, y: 520), length: 330, thickness: 140, angle: 20, filterRatio: 0, tip: ash)
}

// C2. 어두운 바탕 + 부러진 담배 (대비 가장 강함)
let c2 = image { ctx in
    fill(ctx, ink)
    cigarette(ctx, center: CGPoint(x: 330, y: 640), length: 430, thickness: 140, angle: -20, filterRatio: 0.45)
    cigarette(ctx, center: CGPoint(x: 725, y: 520), length: 330, thickness: 140, angle: 20, filterRatio: 0, tip: ember)
}

// C3. 청록 바탕 + 크게 V자로 꺾인 담배와 작은 부스러기
let c3 = image { ctx in
    gradient(ctx, teal, tealDeep)
    cigarette(ctx, center: CGPoint(x: 360, y: 520), length: 470, thickness: 150, angle: 35, filterRatio: 0.42)
    cigarette(ctx, center: CGPoint(x: 690, y: 520), length: 400, thickness: 150, angle: -35, filterRatio: 0, tip: ash)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
    for (x, y, r) in [(512.0, 700.0, 16.0), (470.0, 760.0, 11.0), (560.0, 770.0, 9.0)] {
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}

// E1. 비벼 끈 꽁초 + 체크 배지 (청록)
let e1 = image { ctx in
    gradient(ctx, teal, tealDeep)
    crushedButt(ctx, center: CGPoint(x: 470, y: 640), length: 620, thickness: 130, angle: 0, bend: -40)
    checkBadge(ctx, center: CGPoint(x: 700, y: 330), radius: 150, fillColor: .white, checkColor: tealDeep)
}

// E2. 밝은 바탕 + 꽁초 + 청록 체크 배지
let e2 = image { ctx in
    fill(ctx, paper)
    crushedButt(ctx, center: CGPoint(x: 470, y: 660), length: 620, thickness: 130, angle: 0, bend: -40)
    checkBadge(ctx, center: CGPoint(x: 700, y: 330), radius: 150, fillColor: teal, checkColor: .white)
}

// E3. 재떨이에 비벼 끈 꽁초 + 체크
let e3 = image { ctx in
    gradient(ctx, teal, tealDeep)
    // 재떨이(납작한 반원 그릇)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 200, y: 640, width: 624, height: 170), cornerWidth: 85, cornerHeight: 85, transform: nil))
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor); ctx.fillPath()
    crushedButt(ctx, center: CGPoint(x: 470, y: 640), length: 560, thickness: 120, angle: -12, bend: -45)
    checkBadge(ctx, center: CGPoint(x: 700, y: 310), radius: 140, fillColor: .white, checkColor: tealDeep)
}

let candidates: [(String, String, NSImage)] = [
    ("C1", "청록 + 부러진 담배", c1),
    ("C2", "어두운 + 부러진 담배", c2),
    ("C3", "V자로 꺾인 담배", c3),
    ("E1", "꽁초 + 체크 (청록)", e1),
    ("E2", "꽁초 + 체크 (밝은)", e2),
    ("E3", "재떨이 꽁초 + 체크", e3),
]

func savePNG(_ img: NSImage, _ path: String) {
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for (n, _, img) in candidates { savePNG(img, "\(outDir)/icon-v3-\(n).png") }

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
    let attr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 32, weight: .semibold), .foregroundColor: ink]
    let s = NSAttributedString(string: "\(n). \(name)", attributes: attr)
    s.draw(at: CGPoint(x: r.midX - s.size().width / 2, y: r.maxY + 14))
}
sheet.unlockFocus()
savePNG(sheet, "\(outDir)/icon-candidates-v3.png")
print("ok")
