import AppKit
import SwiftUI

// MARK: - Motion

extension Animation {
    static let lumen = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let lumenSnappy = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let lumenSlow = Animation.spring(response: 0.9, dampingFraction: 0.9)
    static let lumenGlide = Animation.easeInOut(duration: 0.65)
}

extension AnyTransition {
    static var lumenOverlay: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 1.015, anchor: .center)),
            removal: .opacity.combined(with: .scale(scale: 0.99, anchor: .center))
        )
    }
}

// MARK: - Environment

private struct LumenPaletteKey: EnvironmentKey {
    static let defaultValue = AppSettings().palette
}

extension EnvironmentValues {
    var lumenPalette: LumenPalette {
        get { self[LumenPaletteKey.self] }
        set { self[LumenPaletteKey.self] = newValue }
    }
}

// MARK: - Type

enum LumenFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("AvenirNext-DemiBold", size: size).weight(weight)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("AvenirNext-Medium", size: size).weight(weight)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Palette helpers

extension Game {
    func accent(using palette: LumenPalette) -> Color {
        accentHex.flatMap(Color.init(hexString:)) ?? palette.accent
    }
}

extension View {
    /// A soft outer glow used on active cards and primary controls.
    func lumenGlow(_ color: Color, radius: CGFloat = 26, opacity: Double = 0.5) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 10)
    }

    func hairlineBorder(_ color: Color = .white.opacity(0.12), radius: CGFloat, lineWidth: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: lineWidth)
        )
    }
}

// MARK: - Materials

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
    }
}

struct GlassPanel<Content: View>: View {
    var radius: CGFloat = 28
    var padding: CGFloat = 24
    var tint: Color = .white
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .opacity(0.62)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.09), tint.opacity(0.025)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.24), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
    }
}

// MARK: - Textures

enum LumenTextureFactory {
    static let grain: NSImage = {
        let side = 160
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return NSImage(size: NSSize(width: 1, height: 1)) }
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed & 0xFFFF) / 65535.0
        }
        for y in 0..<side {
            for x in 0..<side {
                let value = next()
                let alpha = value > 0.82 ? value * 0.65 : value * 0.16
                rep.setColor(NSColor(white: value, alpha: alpha), atX: x, y: y)
            }
        }
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            rep.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
            return true
        }
    }()
}

struct GrainOverlay: View {
    var opacity: Double = 0.055

    var body: some View {
        Image(nsImage: LumenTextureFactory.grain)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}

// MARK: - Ambient background

struct AmbientBackground: View {
    let palette: LumenPalette
    let settings: AppSettings

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [palette.backgroundTop, palette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if settings.motionEnabled {
                    TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
                        blobs(size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    blobs(size: size, time: 0)
                }

                ThemeTextureLayer(texture: palette.theme.texture, accent: palette.accent)
                    .opacity(0.5)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.22), location: 0),
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.62), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    private func blobs(size: CGSize, time: TimeInterval) -> some View {
        ZStack {
            RadialGradient(
                colors: [palette.accent.opacity(0.30 * settings.ambientIntensity), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size.width * 0.42
            )
            .frame(width: size.width * 0.9, height: size.width * 0.9)
            .offset(
                x: size.width * 0.30 + CGFloat(sin(time * 0.07)) * 55,
                y: -size.height * 0.28 + CGFloat(cos(time * 0.05)) * 38
            )
            .blur(radius: 40)

            RadialGradient(
                colors: [palette.secondary.opacity(0.20 * settings.ambientIntensity), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size.width * 0.32
            )
            .frame(width: size.width * 0.7, height: size.width * 0.7)
            .offset(
                x: -size.width * 0.34 + CGFloat(cos(time * 0.06)) * 46,
                y: size.height * 0.26 + CGFloat(sin(time * 0.045)) * 30
            )
            .blur(radius: 60)
        }
    }
}

private struct ThemeTextureLayer: View {
    let texture: ThemeTexture
    let accent: Color

    var body: some View {
        Canvas { context, size in
            switch texture {
            case .aurora:
                var path = Path()
                for i in 0..<7 {
                    let y = size.height * (0.16 + CGFloat(i) * 0.13)
                    path.move(to: CGPoint(x: -40, y: y))
                    path.addCurve(
                        to: CGPoint(x: size.width + 40, y: y - size.height * 0.09),
                        control1: CGPoint(x: size.width * 0.28, y: y - 90),
                        control2: CGPoint(x: size.width * 0.72, y: y + 110)
                    )
                }
                context.stroke(path, with: .color(accent.opacity(0.055)), lineWidth: 1)

            case .diagonal:
                var path = Path()
                let step: CGFloat = 56
                var x = -size.height
                while x < size.width + size.height {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += step
                }
                context.stroke(path, with: .color(.white.opacity(0.032)), lineWidth: 1)

            case .halftone:
                for row in stride(from: 0, to: Int(size.height), by: 22) {
                    for col in stride(from: 0, to: Int(size.width), by: 22) {
                        let radius = 0.6 + CGFloat((row / 22 + col / 22) % 5) * 0.28
                        let rect = CGRect(x: CGFloat(col), y: CGFloat(row), width: radius, height: radius)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.045)))
                    }
                }

            case .grid:
                var path = Path()
                let step: CGFloat = 72
                for x in stride(from: 0, through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.026)), lineWidth: 1)

            case .vignette:
                let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
                let gradient = Gradient(colors: [.clear, .black.opacity(0.58)])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: min(size.width, size.height) * 0.18,
                        endRadius: max(size.width, size.height) * 0.78
                    )
                )
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - Logo

struct LumenMark: View {
    var size: CGFloat = 34
    var showsWordmark: Bool = true

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                Circle()
                    .trim(from: 0.08, to: 0.32)
                    .stroke(
                        LinearGradient(colors: [.white, .white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-18))
                Circle()
                    .stroke(Color(hex: 0xE8D2A2).opacity(0.75), lineWidth: 1.5)
                    .mask(
                        Rectangle()
                            .frame(width: size, height: size)
                            .rotationEffect(.degrees(155))
                            .offset(x: size * 0.34)
                    )
                Text("L")
                    .font(LumenFont.display(size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: 0.5)
            }
            .frame(width: size, height: size)

            if showsWordmark {
                Text("LUMEN")
                    .font(LumenFont.display(15, weight: .semibold))
                    .tracking(5.5)
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .accessibilityLabel("Lumen")
    }
}

// MARK: - Window chrome

private final class WindowProbeView: NSView {
    var onWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { onWindow?(window) }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    var launchFullScreen: Bool = false
    var isBooting: Bool = false

    final class Coordinator {
        var didScheduleLaunchState = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = WindowProbeView()
        view.onWindow = { window in
            configure(window, coordinator: context.coordinator)
        }
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let window = view.window else { return }
        configure(window, coordinator: context.coordinator)
    }

    private func configure(_ window: NSWindow, coordinator: Coordinator) {
        window.title = "Lumen"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.minSize = NSSize(width: 1180, height: 760)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.hasShadow = true
        if window.frame.width < 1180 {
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
        }

        // Apply the startup preference once, after the boot overlay has finished.
        // AppKit can restore a full-screen window even when the preference is off,
        // so enforce the desired state on a short delay rather than only on entry.
        if !isBooting,
           !coordinator.didScheduleLaunchState,
           window.styleMask.contains(.titled) {
            coordinator.didScheduleLaunchState = true
            let desiredFullScreen = launchFullScreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak window] in
                guard let window, window.styleMask.contains(.titled) else { return }
                let isFullScreen = window.styleMask.contains(.fullScreen)
                guard desiredFullScreen != isFullScreen else { return }
                window.collectionBehavior.insert(.fullScreenPrimary)
                window.toggleFullScreen(nil)
            }
        }
    }
}
