import AppKit
import CoreGraphics
import Foundation

// MARK: - Utilities

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func double(_ lower: Double = 0, _ upper: Double = 1) -> Double {
        lower + (upper - lower) * Double(next() >> 11) / Double(UInt64.max >> 11)
    }
    mutating func int(_ lower: Int, _ upper: Int) -> Int {
        guard upper > lower else { return lower }
        return lower + Int(next() % UInt64(upper - lower))
    }
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255.0,
        green: CGFloat((hex >> 8) & 0xFF) / 255.0,
        blue: CGFloat(hex & 0xFF) / 255.0,
        alpha: alpha
    )
}

func nsColor(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha)
}

func makeContext(width: Int, height: Int) -> (NSBitmapImageRep, CGContext) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: width,
                               pixelsHigh: height,
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let ctx = graphics.cgContext
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    return (rep, ctx)
}

func finish(_ rep: NSBitmapImageRep, _ ctx: CGContext, path: String) {
    ctx.flush()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) [\(rep.pixelsWide)x\(rep.pixelsHigh)]")
}

func linearGradient(_ ctx: CGContext, rect: CGRect, colors: [CGColor], locations: [CGFloat],
                    start: CGPoint? = nil, end: CGPoint? = nil) {
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(gradient,
                           start: start ?? CGPoint(x: rect.midX, y: rect.minY),
                           end: end ?? CGPoint(x: rect.midX, y: rect.maxY),
                           options: [])
    ctx.restoreGState()
}

func radialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor, alpha: CGFloat) {
    let space = CGColorSpaceCreateDeviceRGB()
    let c0 = color.copy(alpha: alpha)!
    let c1 = color.copy(alpha: alpha * 0.32)!
    let c2 = color.copy(alpha: 0)!
    let gradient = CGGradient(colorsSpace: space, colors: [c0, c1, c2] as CFArray, locations: [0, 0.45, 1])!
    ctx.saveGState()
    ctx.drawRadialGradient(gradient,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func glowLine(_ ctx: CGContext, from: CGPoint, to: CGPoint, color: CGColor, width: CGFloat, blur: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: blur, color: color)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: from)
    ctx.addLine(to: to)
    ctx.strokePath()
    ctx.restoreGState()
}

func drawStars(_ ctx: CGContext, in rect: CGRect, count: Int, seed: UInt64, tint: CGColor) {
    var rng = SeededRandom(state: seed)
    for _ in 0..<count {
        let x = rng.double(Double(rect.minX), Double(rect.maxX))
        let y = rng.double(Double(rect.minY), Double(rect.maxY * 0.78))
        let r = rng.double(0.4, 2.1)
        let a = rng.double(0.08, 0.65)
        ctx.setFillColor(tint.copy(alpha: a)!)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        if r > 1.65 {
            ctx.setFillColor(tint.copy(alpha: a * 0.16)!)
            ctx.fillEllipse(in: CGRect(x: x - r * 3, y: y - r * 3, width: r * 7, height: r * 7))
        }
    }
}

func drawNoise(_ ctx: CGContext, width: Int, height: Int, alpha: CGFloat, seed: UInt64) {
    var rng = SeededRandom(state: seed)
    ctx.saveGState()
    for _ in 0..<(width * height / 420) {
        let x = CGFloat(rng.int(0, width))
        let y = CGFloat(rng.int(0, height))
        let white = rng.double() > 0.48
        let c = white ? CGColor(gray: 1, alpha: alpha) : CGColor(gray: 0, alpha: alpha * 0.8)
        ctx.setFillColor(c)
        ctx.fill(CGRect(x: x, y: y, width: 1.2, height: 1.2))
    }
    ctx.restoreGState()
}

func drawVignette(_ ctx: CGContext, rect: CGRect, strength: CGFloat = 0.62) {
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space,
                              colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: strength)] as CFArray,
                              locations: [0.44, 1])!
    ctx.saveGState()
    ctx.drawRadialGradient(gradient,
                           startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: rect.width * 0.16,
                           endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.78,
                           options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}

func save(_ rep: NSBitmapImageRep, to directory: String, name: String) {
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.path) [\(rep.pixelsWide)x\(rep.pixelsHigh)]")
}

// MARK: - Eclipse Protocol

func makeEclipse(to directory: String) {
    let w = 2560, h = 1440
    let (rep, ctx) = makeContext(width: w, height: h)
    let rect = CGRect(x: 0, y: 0, width: w, height: h)

    linearGradient(ctx, rect: rect,
                   colors: [color(0x03050B), color(0x0A1024), color(0x020309)],
                   locations: [0, 0.52, 1])

    radialGlow(ctx, center: CGPoint(x: 1850, y: 590), radius: 1050, color: color(0x345F9D), alpha: 0.24)
    radialGlow(ctx, center: CGPoint(x: 640, y: 980), radius: 780, color: color(0x36406F), alpha: 0.16)
    radialGlow(ctx, center: CGPoint(x: 1870, y: 610), radius: 680, color: color(0xFF8A3A), alpha: 0.18)

    drawStars(ctx, in: rect, count: 920, seed: 0xEC1, tint: color(0xD8E8FF))

    // Eclipsed sun.
    radialGlow(ctx, center: CGPoint(x: 1860, y: 600), radius: 740, color: color(0xFF7A2F), alpha: 0.50)
    radialGlow(ctx, center: CGPoint(x: 1860, y: 600), radius: 440, color: color(0xFFC26A), alpha: 0.30)

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 42, color: color(0xFF8C45, alpha: 0.95))
    ctx.setStrokeColor(color(0xFFB267, alpha: 0.98))
    ctx.setLineWidth(3.2)
    ctx.strokeEllipse(in: CGRect(x: 1860 - 382, y: 600 - 382, width: 764, height: 764))
    ctx.restoreGState()

    ctx.setFillColor(color(0x010104))
    ctx.fillEllipse(in: CGRect(x: 1860 - 374, y: 600 - 374, width: 748, height: 748))
    ctx.setFillColor(color(0x05060B, alpha: 0.94))
    ctx.fillEllipse(in: CGRect(x: 1860 - 350, y: 600 - 350, width: 700, height: 700))

    // Warm rim highlights.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 26, color: color(0xFF9A44, alpha: 0.8))
    ctx.setStrokeColor(color(0xFFB97A, alpha: 0.9))
    ctx.setLineWidth(2.0)
    ctx.addArc(center: CGPoint(x: 1860, y: 600), radius: 377, startAngle: .pi * 0.95, endAngle: .pi * 1.75, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // Rays.
    ctx.saveGState()
    ctx.setFillColor(color(0xFF9B4C, alpha: 0.055))
    for i in 0..<15 {
        let a = Double(i) / 15.0 * .pi * 2 + 0.18
        let spread = 0.018
        let p1 = CGPoint(x: 1860 + cos(a - spread) * 385, y: 600 + sin(a - spread) * 385)
        let p2 = CGPoint(x: 1860 + cos(a + spread) * 385, y: 600 + sin(a + spread) * 385)
        let p3 = CGPoint(x: 1860 + cos(a) * 1560, y: 600 + sin(a) * 1560)
        ctx.move(to: p1); ctx.addLine(to: p3); ctx.addLine(to: p2); ctx.closePath(); ctx.fillPath()
    }
    ctx.restoreGState()

    // Lens flare accents.
    for (x, y, r, a) in [(1520.0, 760.0, 8.0, 0.55), (1320.0, 900.0, 4.0, 0.35), (1110.0, 1020.0, 11.0, 0.18)] {
        radialGlow(ctx, center: CGPoint(x: x, y: y), radius: r * 5, color: color(0x8CCBFF), alpha: a)
    }

    // Atmospheric light behind the horizon.
    radialGlow(ctx, center: CGPoint(x: 1500, y: 1000), radius: 1040, color: color(0x5977B5), alpha: 0.17)

    // Distant mountain ridges.
    func ridge(_ points: [(CGFloat, CGFloat)], fill: CGColor, rim: CGColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 1440))
        path.addLine(to: CGPoint(x: 0, y: points[0].1))
        for p in points { path.addLine(to: CGPoint(x: p.0, y: p.1)) }
        path.addLine(to: CGPoint(x: 2560, y: 1440))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(fill)
        ctx.fillPath()
        let line = CGMutablePath()
        line.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for p in points.dropFirst() { line.addLine(to: CGPoint(x: p.0, y: p.1)) }
        ctx.addPath(line)
        ctx.setStrokeColor(rim)
        ctx.setLineWidth(1.2)
        ctx.strokePath()
    }

    ridge([(0, 1030), (220, 930), (470, 1005), (720, 890), (960, 970), (1230, 860), (1500, 950), (1790, 840), (2070, 930), (2320, 850), (2560, 940)],
          fill: color(0x0B1426, alpha: 0.86), rim: color(0x6A8FC7, alpha: 0.20))
    ridge([(0, 1130), (260, 1030), (530, 1100), (780, 980), (1050, 1070), (1360, 960), (1650, 1060), (1920, 950), (2200, 1040), (2440, 970), (2560, 1020)],
          fill: color(0x060B16, alpha: 0.94), rim: color(0x5A82BC, alpha: 0.12))
    ridge([(0, 1230), (300, 1150), (600, 1210), (920, 1105), (1230, 1190), (1540, 1090), (1840, 1170), (2150, 1060), (2420, 1140), (2560, 1110)],
          fill: color(0x03060B), rim: color(0xFF9A55, alpha: 0.10))

    // Ground haze.
    linearGradient(ctx, rect: CGRect(x: 0, y: 1080, width: 2560, height: 360),
                   colors: [color(0x08111F, alpha: 0), color(0x05090F, alpha: 0.74), color(0x020409)],
                   locations: [0, 0.7, 1])

    // Lone traveler silhouette.
    let px: CGFloat = 720, py: CGFloat = 1258
    radialGlow(ctx, center: CGPoint(x: px, y: py - 5), radius: 150, color: color(0xFF9E52), alpha: 0.24)
    ctx.setFillColor(color(0x010203, alpha: 0.97))
    ctx.fillEllipse(in: CGRect(x: px - 19, y: py - 78, width: 38, height: 38))
    let body = CGMutablePath()
    body.move(to: CGPoint(x: px - 34, y: py - 34))
    body.addQuadCurve(to: CGPoint(x: px + 34, y: py - 34), control: CGPoint(x: px, y: py - 90))
    body.addLine(to: CGPoint(x: px + 42, y: py + 132))
    body.addLine(to: CGPoint(x: px - 42, y: py + 132))
    body.closeSubpath()
    ctx.addPath(body); ctx.fillPath()
    glowLine(ctx, from: CGPoint(x: px - 20, y: py - 55), to: CGPoint(x: px + 14, y: py - 55), color: color(0xFFB466, alpha: 0.55), width: 1.2, blur: 8)
    glowLine(ctx, from: CGPoint(x: px + 32, y: py - 24), to: CGPoint(x: px + 48, y: py + 112), color: color(0xFF9B50, alpha: 0.28), width: 1.0, blur: 7)

    drawVignette(ctx, rect: rect, strength: 0.64)
    drawNoise(ctx, width: w, height: h, alpha: 0.032, seed: 0x99EC)
    save(rep, to: directory, name: "showcase-eclipse-hero.png")

    // Icon square.
    makeEclipseIcon(to: directory)
}

func makeEclipseIcon(to directory: String) {
    let s = 1024
    let (rep, ctx) = makeContext(width: s, height: s)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    linearGradient(ctx, rect: rect, colors: [color(0x05070D), color(0x0C1224), color(0x020309)], locations: [0, 0.55, 1])
    radialGlow(ctx, center: CGPoint(x: 512, y: 512), radius: 520, color: color(0xFF7C33), alpha: 0.34)
    ctx.setFillColor(color(0x010104))
    ctx.fillEllipse(in: CGRect(x: 512 - 260, y: 512 - 260, width: 520, height: 520))
    ctx.setShadow(offset: .zero, blur: 30, color: color(0xFFA05E, alpha: 0.9))
    ctx.setStrokeColor(color(0xFFB876, alpha: 0.95))
    ctx.setLineWidth(8)
    ctx.strokeEllipse(in: CGRect(x: 512 - 264, y: 512 - 264, width: 528, height: 528))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.addArc(center: CGPoint(x: 512, y: 512), radius: 300, startAngle: .pi * 0.1, endAngle: .pi * 0.72, clockwise: false)
    ctx.setStrokeColor(color(0x7AD9FF, alpha: 0.10))
    ctx.setLineWidth(2)
    ctx.strokePath()
    drawVignette(ctx, rect: rect, strength: 0.42)
    drawNoise(ctx, width: s, height: s, alpha: 0.026, seed: 0xEC1A)
    save(rep, to: directory, name: "showcase-eclipse-icon.png")
}

// MARK: - Neon Reverie

func makeNeon(to directory: String) {
    let w = 2560, h = 1440
    let (rep, ctx) = makeContext(width: w, height: h)
    let rect = CGRect(x: 0, y: 0, width: w, height: h)

    linearGradient(ctx, rect: rect,
                   colors: [color(0x080412), color(0x16061F), color(0x07030B)],
                   locations: [0, 0.52, 1])
    radialGlow(ctx, center: CGPoint(x: 1280, y: 560), radius: 1000, color: color(0xFF2D9A), alpha: 0.28)
    radialGlow(ctx, center: CGPoint(x: 470, y: 280), radius: 680, color: color(0x1E3CFF), alpha: 0.16)
    radialGlow(ctx, center: CGPoint(x: 2100, y: 800), radius: 720, color: color(0xFF1E7A), alpha: 0.12)
    drawStars(ctx, in: rect, count: 380, seed: 0x4E0, tint: color(0xFFD7F2))

    // Retro sun.
    let sunCenter = CGPoint(x: 1280, y: 620)
    radialGlow(ctx, center: sunCenter, radius: 690, color: color(0xFF4C87), alpha: 0.48)
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: 1280 - 330, y: 620 - 330, width: 660, height: 660))
    ctx.clip()
    linearGradient(ctx, rect: CGRect(x: 950, y: 290, width: 660, height: 660),
                   colors: [color(0xFFD36A), color(0xFF7A43), color(0xE52388), color(0x6A137A)],
                   locations: [0, 0.38, 0.72, 1])
    // Slats.
    ctx.setFillColor(color(0x100519, alpha: 0.86))
    for i in 0..<13 {
        let y = 720 + CGFloat(i) * 24 + CGFloat(i * i) * 1.6
        ctx.fill(CGRect(x: 900, y: y, width: 780, height: 5 + CGFloat(i) * 1.3))
    }
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 28, color: color(0xFF4F97, alpha: 0.8))
    ctx.setStrokeColor(color(0xFFC87E, alpha: 0.5))
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: 1280 - 336, y: 620 - 336, width: 672, height: 672))
    ctx.restoreGState()

    // City haze.
    radialGlow(ctx, center: CGPoint(x: 1280, y: 870), radius: 1150, color: color(0xFF2C84), alpha: 0.23)
    linearGradient(ctx, rect: CGRect(x: 0, y: 730, width: 2560, height: 330),
                   colors: [color(0x2A0A35, alpha: 0), color(0x481144, alpha: 0.35), color(0x090410, alpha: 0.9)],
                   locations: [0, 0.55, 1])

    // Skyline.
    var rng = SeededRandom(state: 0xBEEF)
    var x: CGFloat = -40
    while x < 2600 {
        let bw = CGFloat(rng.double(38, 100))
        let bh = CGFloat(rng.double(80, 330))
        let y = 870 - bh
        ctx.setFillColor(color(0x07030D, alpha: 0.98))
        ctx.fill(CGRect(x: x, y: y, width: bw, height: bh + 30))
        if rng.double() > 0.55 {
            ctx.setStrokeColor(color(0x1B0924))
            ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: x + bw * 0.5, y: y))
            ctx.addLine(to: CGPoint(x: x + bw * 0.5, y: y - rng.double(25, 80)))
            ctx.strokePath()
        }
        for wy in stride(from: y + 16, to: y + bh - 12, by: 18) {
            for wx in stride(from: x + 9, to: x + bw - 8, by: 14) {
                if rng.double() > 0.55 {
                    let c = rng.double() > 0.5 ? color(0x4DE7FF, alpha: 0.62) : color(0xFF8BCB, alpha: 0.48)
                    ctx.setFillColor(c)
                    ctx.fill(CGRect(x: wx, y: wy, width: 2.2, height: 3.4))
                }
            }
        }
        x += bw + CGFloat(rng.double(4, 15))
    }

    // Grid floor.
    let horizonY: CGFloat = 880
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 9, color: color(0x35E8FF, alpha: 0.75))
    for i in -24...24 {
        let bx = 1280 + CGFloat(i) * 160
        ctx.setStrokeColor(color(i % 3 == 0 ? 0xFF4DBB : 0x32E4FF, alpha: 0.20))
        ctx.setLineWidth(1.2)
        ctx.move(to: CGPoint(x: 1280, y: horizonY))
        ctx.addLine(to: CGPoint(x: bx, y: 1440))
        ctx.strokePath()
    }
    var step: CGFloat = 2
    var y = horizonY + step
    var i = 0
    while y < 1460 {
        ctx.setStrokeColor(color(i % 4 == 0 ? 0xFF5CC4 : 0x37E1FF, alpha: 0.20))
        ctx.setLineWidth(i % 4 == 0 ? 1.6 : 1.0)
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: 2560, y: y))
        ctx.strokePath()
        i += 1
        step *= 1.28
        y += step
    }
    ctx.restoreGState()

    // Horizon glow line.
    glowLine(ctx, from: CGPoint(x: 0, y: horizonY), to: CGPoint(x: 2560, y: horizonY), color: color(0x68EDFF, alpha: 0.55), width: 1.4, blur: 18)

    // Wet-floor reflection bands.
    for j in 0..<7 {
        let ry = 1010 + CGFloat(j) * 40
        let inset = CGFloat(j) * 120
        let gradRect = CGRect(x: inset, y: ry, width: 2560 - inset * 2, height: 3)
        linearGradient(ctx, rect: gradRect,
                       colors: [color(0xFF4DA0, alpha: 0), color(0xFF6EC8, alpha: 0.20), color(0x41D9FF, alpha: 0)],
                       locations: [0, 0.5, 1],
                       start: CGPoint(x: gradRect.minX, y: ry),
                       end: CGPoint(x: gradRect.maxX, y: ry))
    }

    // Floating vehicle silhouette.
    ctx.saveGState()
    ctx.translateBy(x: 2010, y: 420)
    ctx.rotate(by: -0.05)
    radialGlow(ctx, center: .zero, radius: 140, color: color(0x47DEFF), alpha: 0.25)
    ctx.setFillColor(color(0x05030A))
    let car = CGMutablePath()
    car.move(to: CGPoint(x: -95, y: 6))
    car.addQuadCurve(to: CGPoint(x: -30, y: -26), control: CGPoint(x: -70, y: -30))
    car.addLine(to: CGPoint(x: 38, y: -24))
    car.addQuadCurve(to: CGPoint(x: 100, y: 2), control: CGPoint(x: 82, y: -14))
    car.addLine(to: CGPoint(x: 56, y: 14))
    car.addLine(to: CGPoint(x: -58, y: 14))
    car.closeSubpath()
    ctx.addPath(car); ctx.fillPath()
    glowLine(ctx, from: CGPoint(x: 50, y: 12), to: CGPoint(x: 104, y: 8), color: color(0xFF6BD8, alpha: 0.9), width: 2.4, blur: 12)
    glowLine(ctx, from: CGPoint(x: -58, y: 12), to: CGPoint(x: -98, y: 10), color: color(0x56D8FF, alpha: 0.8), width: 2.0, blur: 10)
    ctx.restoreGState()

    drawVignette(ctx, rect: rect, strength: 0.58)
    drawNoise(ctx, width: w, height: h, alpha: 0.030, seed: 0x4EEB)
    save(rep, to: directory, name: "showcase-neon-hero.png")

    makeNeonIcon(to: directory)
}

func makeNeonIcon(to directory: String) {
    let s = 1024
    let (rep, ctx) = makeContext(width: s, height: s)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    linearGradient(ctx, rect: rect, colors: [color(0x090412), color(0x1A0524)], locations: [0, 1])
    radialGlow(ctx, center: CGPoint(x: 512, y: 470), radius: 430, color: color(0xFF438D), alpha: 0.40)
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: 512 - 230, y: 430 - 230, width: 460, height: 460))
    ctx.clip()
    linearGradient(ctx, rect: CGRect(x: 280, y: 200, width: 464, height: 464),
                   colors: [color(0xFFD46F), color(0xFF7648), color(0xD91D85)], locations: [0, 0.5, 1])
    ctx.setFillColor(color(0x12041B))
    for i in 0..<9 {
        ctx.fill(CGRect(x: 260, y: 530 + CGFloat(i) * 32, width: 520, height: 7 + CGFloat(i) * 2))
    }
    ctx.restoreGState()
    ctx.setShadow(offset: .zero, blur: 22, color: color(0xFF52A0, alpha: 0.9))
    ctx.setStrokeColor(color(0xFFC77D, alpha: 0.45))
    ctx.setLineWidth(4)
    ctx.strokeEllipse(in: CGRect(x: 512 - 234, y: 430 - 234, width: 468, height: 468))
    // Grid hint.
    ctx.setShadow(offset: .zero, blur: 10, color: color(0x3DE2FF, alpha: 0.8))
    for i in -5...5 {
        ctx.setStrokeColor(color(0x35E4FF, alpha: 0.22))
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 512, y: 800))
        ctx.addLine(to: CGPoint(x: 512 + CGFloat(i) * 150, y: 1024))
        ctx.strokePath()
    }
    for j in 0..<4 {
        ctx.move(to: CGPoint(x: 0, y: 820 + CGFloat(j) * 56))
        ctx.addLine(to: CGPoint(x: 1024, y: 820 + CGFloat(j) * 56))
        ctx.strokePath()
    }
    drawVignette(ctx, rect: rect, strength: 0.45)
    drawNoise(ctx, width: s, height: s, alpha: 0.024, seed: 0x4E1C)
    save(rep, to: directory, name: "showcase-neon-icon.png")
}

// MARK: - Verdant

func makeVerdant(to directory: String) {
    let w = 2560, h = 1440
    let (rep, ctx) = makeContext(width: w, height: h)
    let rect = CGRect(x: 0, y: 0, width: w, height: h)

    linearGradient(ctx, rect: rect,
                   colors: [color(0x03110F), color(0x0B2A23), color(0x020807)],
                   locations: [0, 0.46, 1])
    radialGlow(ctx, center: CGPoint(x: 1580, y: 390), radius: 980, color: color(0xE8D493), alpha: 0.32)
    radialGlow(ctx, center: CGPoint(x: 620, y: 880), radius: 860, color: color(0x2B8F70), alpha: 0.18)
    radialGlow(ctx, center: CGPoint(x: 2100, y: 1020), radius: 720, color: color(0x1C6B5F), alpha: 0.16)
    drawStars(ctx, in: rect, count: 270, seed: 0x60D, tint: color(0xD9FFF3))

    // Moon.
    let mc = CGPoint(x: 1580, y: 390)
    radialGlow(ctx, center: mc, radius: 620, color: color(0xF5E9BE), alpha: 0.38)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 48, color: color(0xF8EAC5, alpha: 0.65))
    ctx.setFillColor(color(0xF4EDCF, alpha: 0.92))
    ctx.fillEllipse(in: CGRect(x: mc.x - 128, y: mc.y - 128, width: 256, height: 256))
    ctx.restoreGState()
    ctx.setFillColor(color(0xDED0A1, alpha: 0.26))
    ctx.fillEllipse(in: CGRect(x: mc.x - 48, y: mc.y - 55, width: 58, height: 58))
    ctx.fillEllipse(in: CGRect(x: mc.x + 28, y: mc.y + 22, width: 28, height: 28))
    ctx.fillEllipse(in: CGRect(x: mc.x - 10, y: mc.y + 66, width: 17, height: 17))

    // Light shafts.
    ctx.saveGState()
    ctx.setBlendMode(.screen)
    ctx.setFillColor(color(0xE8DC9B, alpha: 0.055))
    for i in 0..<7 {
        let x0 = 1450 + CGFloat(i) * 70
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x0, y: 400))
        p.addLine(to: CGPoint(x: x0 + 44, y: 400))
        p.addLine(to: CGPoint(x: x0 - 500 + CGFloat(i) * 150, y: 1440))
        p.addLine(to: CGPoint(x: x0 - 660 + CGFloat(i) * 150, y: 1440))
        p.closeSubpath()
        ctx.addPath(p); ctx.fillPath()
    }
    ctx.restoreGState()

    // Distant mountains.
    func mountain(_ points: [(CGFloat, CGFloat)], fill: CGColor, stroke: CGColor, width: CGFloat = 1) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 1440))
        path.addLine(to: CGPoint(x: 0, y: points[0].1))
        for p in points { path.addLine(to: CGPoint(x: p.0, y: p.1)) }
        path.addLine(to: CGPoint(x: 2560, y: 1440))
        path.closeSubpath()
        ctx.addPath(path); ctx.setFillColor(fill); ctx.fillPath()
        let l = CGMutablePath()
        l.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for p in points.dropFirst() { l.addLine(to: CGPoint(x: p.0, y: p.1)) }
        ctx.addPath(l); ctx.setStrokeColor(stroke); ctx.setLineWidth(width); ctx.strokePath()
    }

    mountain([(0, 880), (300, 720), (540, 830), (790, 660), (1060, 850), (1320, 690), (1610, 840), (1900, 650), (2180, 820), (2400, 730), (2560, 800)],
             fill: color(0x0A2A25, alpha: 0.70), stroke: color(0x8AC8AE, alpha: 0.12))
    mountain([(0, 1010), (260, 880), (520, 990), (810, 820), (1100, 980), (1430, 830), (1740, 1000), (2030, 850), (2300, 990), (2560, 900)],
             fill: color(0x061A16, alpha: 0.88), stroke: color(0x6CAF92, alpha: 0.15))
    mountain([(0, 1140), (320, 1030), (600, 1130), (930, 990), (1260, 1120), (1600, 1000), (1910, 1120), (2240, 1010), (2560, 1100)],
             fill: color(0x030C0A, alpha: 0.96), stroke: color(0xB6D6A6, alpha: 0.10))

    // Forest spires.
    var rng = SeededRandom(state: 0xF0E5)
    for layer in 0..<3 {
        let baseY: CGFloat = 1290 + CGFloat(layer) * 38
        let alpha: CGFloat = 0.50 + CGFloat(layer) * 0.22
        let count = 130
        for _ in 0..<count {
            let x = CGFloat(rng.double(-40, 2600))
            let height = CGFloat(rng.double(100, 420)) * (1 - CGFloat(layer) * 0.08)
            let width = height * CGFloat(rng.double(0.14, 0.22))
            ctx.setFillColor(color(0x020807, alpha: alpha))
            let tree = CGMutablePath()
            tree.move(to: CGPoint(x: x, y: baseY))
            tree.addLine(to: CGPoint(x: x - width, y: baseY))
            tree.addLine(to: CGPoint(x: x - width * 0.22, y: baseY - height * 0.45))
            tree.addLine(to: CGPoint(x: x - width * 0.55, y: baseY - height * 0.45))
            tree.addLine(to: CGPoint(x: x, y: baseY - height))
            tree.addLine(to: CGPoint(x: x + width * 0.55, y: baseY - height * 0.45))
            tree.addLine(to: CGPoint(x: x + width * 0.22, y: baseY - height * 0.45))
            tree.addLine(to: CGPoint(x: x + width, y: baseY))
            tree.closeSubpath()
            ctx.addPath(tree); ctx.fillPath()
        }
    }

    // Stream glow.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: 980, y: 1120, width: 840, height: 300))
    ctx.clip()
    radialGlow(ctx, center: CGPoint(x: 1410, y: 1280), radius: 540, color: color(0x9ED9B0), alpha: 0.10)
    ctx.restoreGState()

    // Fireflies.
    var frng = SeededRandom(state: 0xF17E)
    for _ in 0..<160 {
        let x = CGFloat(frng.double(100, 2450))
        let y = CGFloat(frng.double(580, 1320))
        let r = CGFloat(frng.double(0.8, 2.4))
        let a = CGFloat(frng.double(0.20, 0.72))
        radialGlow(ctx, center: CGPoint(x: x, y: y), radius: r * 6, color: color(0xE9F5A8), alpha: a)
        ctx.setFillColor(color(0xF6F7C8, alpha: a))
        ctx.fillEllipse(in: CGRect(x: x - r * 0.45, y: y - r * 0.45, width: r, height: r))
    }

    // Ground mist.
    linearGradient(ctx, rect: CGRect(x: 0, y: 1040, width: 2560, height: 400),
                   colors: [color(0x071813, alpha: 0), color(0x0A201A, alpha: 0.38), color(0x020706, alpha: 0.82)],
                   locations: [0, 0.55, 1])

    drawVignette(ctx, rect: rect, strength: 0.62)
    drawNoise(ctx, width: w, height: h, alpha: 0.030, seed: 0x6EEB)
    save(rep, to: directory, name: "showcase-verdant-hero.png")

    makeVerdantIcon(to: directory)
}

func makeVerdantIcon(to directory: String) {
    let s = 1024
    let (rep, ctx) = makeContext(width: s, height: s)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    linearGradient(ctx, rect: rect, colors: [color(0x03110F), color(0x0A2A22), color(0x020706)], locations: [0, 0.5, 1])
    radialGlow(ctx, center: CGPoint(x: 540, y: 430), radius: 460, color: color(0xE9DC9F), alpha: 0.30)
    ctx.setFillColor(color(0xEFE7C6, alpha: 0.92))
    ctx.setShadow(offset: .zero, blur: 38, color: color(0xF4E9C1, alpha: 0.55))
    ctx.fillEllipse(in: CGRect(x: 380, y: 270, width: 300, height: 300))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    // Layered leaf ring.
    for i in 0..<5 {
        let inset = CGFloat(i) * 52
        ctx.setStrokeColor(color(0x7FC9A8, alpha: 0.10 + CGFloat(i) * 0.018))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 150 + inset, y: 470 + inset * 0.35, width: 724 - inset * 2, height: 300 - inset))
    }
    for i in 0..<34 {
        let a = Double(i) / 34 * .pi * 2
        let x = 512 + cos(a) * 290
        let y = 800 + sin(a) * 110
        ctx.setFillColor(color(0x0A211A, alpha: 0.9))
        let leaf = CGMutablePath()
        leaf.move(to: CGPoint(x: x, y: y))
        leaf.addQuadCurve(to: CGPoint(x: x + cos(a) * 100, y: y + sin(a) * 70), control: CGPoint(x: x + cos(a + 0.8) * 70, y: y + sin(a + 0.8) * 70))
        leaf.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + cos(a - 0.4) * 55, y: y + sin(a - 0.4) * 45))
        ctx.addPath(leaf); ctx.fillPath()
    }
    drawVignette(ctx, rect: rect, strength: 0.40)
    drawNoise(ctx, width: s, height: s, alpha: 0.024, seed: 0x6E1C)
    save(rep, to: directory, name: "showcase-verdant-icon.png")
}

// MARK: - App icon

func makeAppIcon(to directory: String) {
    let s = 1024
    let (rep, ctx) = makeContext(width: s, height: s)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    ctx.clear(rect)

    let inset: CGFloat = 64
    let iconRect = CGRect(x: inset, y: inset, width: CGFloat(s) - inset * 2, height: CGFloat(s) - inset * 2)
    let squircle = NSBezierPath(roundedRect: iconRect, xRadius: 228, yRadius: 228).cgPath
    ctx.saveGState()
    ctx.addPath(squircle); ctx.clip()
    linearGradient(ctx, rect: iconRect, colors: [color(0x0A1019), color(0x04060A)], locations: [0, 1])
    radialGlow(ctx, center: CGPoint(x: 720, y: 310), radius: 620, color: color(0x4DCBFF), alpha: 0.28)
    radialGlow(ctx, center: CGPoint(x: 330, y: 760), radius: 560, color: color(0x7B61FF), alpha: 0.20)
    radialGlow(ctx, center: CGPoint(x: 700, y: 760), radius: 360, color: color(0xE8C36A), alpha: 0.10)
    // Star field.
    var rng = SeededRandom(state: 0x1C0)
    for _ in 0..<180 {
        let x = CGFloat(rng.double(Double(iconRect.minX), Double(iconRect.maxX)))
        let y = CGFloat(rng.double(Double(iconRect.minY), Double(iconRect.maxY)))
        let r = CGFloat(rng.double(0.6, 2.4))
        ctx.setFillColor(color(0xEAF9FF, alpha: CGFloat(rng.double(0.04, 0.42))))
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }
    // Orbit ring.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 36, color: color(0x64E4FF, alpha: 0.75))
    ctx.setStrokeColor(color(0xA8F0FF, alpha: 0.72))
    ctx.setLineWidth(7)
    ctx.strokeEllipse(in: CGRect(x: 512 - 288, y: 512 - 288, width: 576, height: 576))
    ctx.restoreGState()
    ctx.setStrokeColor(color(0xFFFFFF, alpha: 0.12))
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: 512 - 322, y: 512 - 322, width: 644, height: 644))
    // Crescent arc accent.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 24, color: color(0xFFD582, alpha: 0.9))
    ctx.setStrokeColor(color(0xFFD18A, alpha: 0.92))
    ctx.setLineWidth(9)
    ctx.addArc(center: CGPoint(x: 512, y: 512), radius: 288, startAngle: -.pi * 0.05, endAngle: .pi * 0.42, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()
    // Stylised L.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 28, color: color(0x9AEFFF, alpha: 0.75))
    ctx.setFillColor(color(0xF4FDFF, alpha: 0.98))
    let lpath = CGMutablePath()
    lpath.move(to: CGPoint(x: 410, y: 330))
    lpath.addLine(to: CGPoint(x: 475, y: 330))
    lpath.addLine(to: CGPoint(x: 475, y: 636))
    lpath.addLine(to: CGPoint(x: 636, y: 636))
    lpath.addLine(to: CGPoint(x: 636, y: 705))
    lpath.addLine(to: CGPoint(x: 410, y: 705))
    lpath.closeSubpath()
    ctx.addPath(lpath); ctx.fillPath()
    ctx.restoreGState()
    // Horizon sheen.
    linearGradient(ctx, rect: CGRect(x: 64, y: 820, width: 896, height: 140),
                   colors: [color(0x9FE8FF, alpha: 0), color(0x9FE8FF, alpha: 0.07), color(0x9FE8FF, alpha: 0)],
                   locations: [0, 0.5, 1])
    drawNoise(ctx, width: 1024, height: 1024, alpha: 0.020, seed: 0x1C0A)
    ctx.restoreGState()

    // Inner rim.
    ctx.setStrokeColor(color(0xFFFFFF, alpha: 0.14))
    ctx.setLineWidth(2)
    ctx.addPath(squircle)
    ctx.strokePath()

    save(rep, to: directory, name: "AppIcon-1024.png")
}

// MARK: - Main

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Lumen/Lumen/Resources"
let iconOut = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Lumen/Lumen/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: iconOut, withIntermediateDirectories: true)

makeEclipse(to: output)
makeNeon(to: output)
makeVerdant(to: output)
makeAppIcon(to: iconOut)
