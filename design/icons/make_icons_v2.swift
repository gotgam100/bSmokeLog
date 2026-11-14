// 금연 이미지 쪽 앱 아이콘 후보 (v2). 1024x1024 PNG + 비교 시트.
// 실행: swift design/icons/make_icons_v2.swift <출력 폴더>
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

// 1. 금연 표시: 원 + 사선 + 담배 (가장 직관적)
let noSmoking = image { ctx in
    fill(ctx, paper)
    cigarette(ctx, center: CGPoint(x: 512, y: 512), length: 560, thickness: 110, angle: 0, tip: ash)
    ctx.setStrokeColor(slash.cgColor); ctx.setLineWidth(70)
    ctx.strokeEllipse(in: CGRect(x: 187, y: 187, width: 650, height: 650))
    line(ctx, [CGPoint(x: 282, y: 282), CGPoint(x: 742, y: 742)], width: 70, color: slash)
}

// 2. 청록 금연 표시: 같은 의미를 앱 색으로 부드럽게
let noSmokingTeal = image { ctx in
    gradient(ctx, teal, tealDeep)
    cigarette(ctx, center: CGPoint(x: 512, y: 512), length: 560, thickness: 110, angle: 0, tip: tealSoft)
    ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(64)
    ctx.strokeEllipse(in: CGRect(x: 192, y: 192, width: 640, height: 640))
    line(ctx, [CGPoint(x: 286, y: 286), CGPoint(x: 738, y: 738)], width: 64, color: .white)
}

// 3. 부러진 담배: 끊는다는 뜻
let broken = image { ctx in
    fill(ctx, tealSoft)
    cigarette(ctx, center: CGPoint(x: 330, y: 580), length: 420, thickness: 140, angle: -20, filterRatio: 0.45)
    cigarette(ctx, center: CGPoint(x: 720, y: 470), length: 330, thickness: 140, angle: 20, filterRatio: 0, tip: ash)
}

// 4. 불씨 대신 새싹: 담배 끝에서 잎이 자람
let sprout = image { ctx in
    fill(ctx, paper)
    cigarette(ctx, center: CGPoint(x: 440, y: 700), length: 620, thickness: 130, angle: 0, tip: nil)
    line(ctx, [CGPoint(x: 750, y: 640), CGPoint(x: 750, y: 400)], width: 30, color: leaf)
    leafShape(ctx, base: CGPoint(x: 750, y: 450), tip: CGPoint(x: 580, y: 280), width: 90, color: leaf)
    leafShape(ctx, base: CGPoint(x: 750, y: 410), tip: CGPoint(x: 920, y: 240), width: 90, color: leaf)
}

// 5. 꺼진 담배 + 체크: 오늘도 잘 참았다
let check = image { ctx in
    gradient(ctx, teal, tealDeep)
    cigarette(ctx, center: CGPoint(x: 512, y: 700), length: 560, thickness: 100, angle: 0, tip: ash)
    line(ctx, [CGPoint(x: 330, y: 400), CGPoint(x: 460, y: 520), CGPoint(x: 700, y: 260)], width: 80, color: .white)
}

// 6. 점점 짧아지는 담배 세 개: 줄여 가는 기록
let shorter = image { ctx in
    fill(ctx, tealSoft)
    let lengths: [CGFloat] = [620, 450, 280]
    for (i, l) in lengths.enumerated() {
        let y = 340 + CGFloat(i) * 170
        cigarette(ctx, center: CGPoint(x: 202 + l / 2, y: y), length: l, thickness: 96, angle: 0,
                  filterRatio: 140 / l, tip: i == 2 ? teal : ash)
    }
}

let candidates: [(String, String, NSImage)] = [
    ("A", "금연 표시", noSmoking),
    ("B", "청록 금연 표시", noSmokingTeal),
    ("C", "부러진 담배", broken),
    ("D", "담배 끝 새싹", sprout),
    ("E", "꺼진 담배 + 체크", check),
    ("F", "짧아지는 담배", shorter),
]

func savePNG(_ img: NSImage, _ path: String) {
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for (n, _, img) in candidates { savePNG(img, "\(outDir)/icon-v2-\(n).png") }

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
savePNG(sheet, "\(outDir)/icon-candidates-v2.png")
print("ok")
