import SwiftUI

enum ThemeStyle: String, CaseIterable, Codable, Identifiable {
    case aurora
    case carbon
    case prism
    case deck
    case noir

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aurora: "Aurora"
        case .carbon: "Carbon"
        case .prism: "Prism"
        case .deck: "Deck"
        case .noir: "Noir"
        }
    }

    var chineseName: String {
        switch self {
        case .aurora: "极光"
        case .carbon: "碳纤"
        case .prism: "棱镜"
        case .deck: "深海"
        case .noir: "鎏金"
        }
    }

    var inspiration: String {
        switch self {
        case .aurora: "PlayStation 灵感"
        case .carbon: "Xbox 灵感"
        case .prism: "Switch 灵感"
        case .deck: "Steam 灵感"
        case .noir: "Lumen 签名"
        }
    }

    var accent: Color {
        switch self {
        case .aurora: Color(hex: 0x70E7FF)
        case .carbon: Color(hex: 0xB7FF4C)
        case .prism: Color(hex: 0xFF526B)
        case .deck: Color(hex: 0x69C2FF)
        case .noir: Color(hex: 0xE8D2A2)
        }
    }

    var accentSecondary: Color {
        switch self {
        case .aurora: Color(hex: 0x8C7CFF)
        case .carbon: Color(hex: 0x51E6B4)
        case .prism: Color(hex: 0x39D8FF)
        case .deck: Color(hex: 0x2D6DFF)
        case .noir: Color(hex: 0xC28E54)
        }
    }

    var backgroundTop: Color {
        switch self {
        case .aurora: Color(hex: 0x060A12)
        case .carbon: Color(hex: 0x080C09)
        case .prism: Color(hex: 0x0A0D1A)
        case .deck: Color(hex: 0x050A13)
        case .noir: Color(hex: 0x0A0807)
        }
    }

    var backgroundBottom: Color {
        switch self {
        case .aurora: Color(hex: 0x020306)
        case .carbon: Color(hex: 0x020403)
        case .prism: Color(hex: 0x03040A)
        case .deck: Color(hex: 0x02050B)
        case .noir: Color(hex: 0x030202)
        }
    }

    var titleDesign: Font.Design {
        switch self {
        case .prism: .rounded
        case .noir: .serif
        default: .default
        }
    }

    var cardRadius: CGFloat {
        switch self {
        case .aurora: 24
        case .carbon: 14
        case .prism: 26
        case .deck: 12
        case .noir: 18
        }
    }

    var texture: ThemeTexture {
        switch self {
        case .aurora: .aurora
        case .carbon: .diagonal
        case .prism: .halftone
        case .deck: .grid
        case .noir: .vignette
        }
    }
}

enum ThemeTexture {
    case aurora
    case diagonal
    case halftone
    case grid
    case vignette
}

struct AppSettings: Codable, Equatable {
    var theme: ThemeStyle = .aurora
    var customAccentHex: String?
    var motionEnabled: Bool = true
    var grainEnabled: Bool = true
    var clockVisible: Bool = true
    var launchFullScreen: Bool = true
    var hapticsEnabled: Bool = true
    var ambientIntensity: Double = 0.92
    var didSeedShowcase: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(ThemeStyle.self, forKey: .theme) ?? .aurora
        customAccentHex = try c.decodeIfPresent(String.self, forKey: .customAccentHex)
        motionEnabled = try c.decodeIfPresent(Bool.self, forKey: .motionEnabled) ?? true
        grainEnabled = try c.decodeIfPresent(Bool.self, forKey: .grainEnabled) ?? true
        clockVisible = try c.decodeIfPresent(Bool.self, forKey: .clockVisible) ?? true
        launchFullScreen = try c.decodeIfPresent(Bool.self, forKey: .launchFullScreen) ?? true
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        ambientIntensity = try c.decodeIfPresent(Double.self, forKey: .ambientIntensity) ?? 0.92
        didSeedShowcase = try c.decodeIfPresent(Bool.self, forKey: .didSeedShowcase) ?? false
    }

    var effectiveAccent: Color {
        customAccentHex.flatMap(Color.init(hexString:)) ?? theme.accent
    }

    var palette: LumenPalette {
        LumenPalette(theme: theme, accent: effectiveAccent)
    }
}

struct LumenPalette {
    let theme: ThemeStyle
    let accent: Color
    let secondary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let surface: Color
    let surfaceRaised: Color
    let textPrimary: Color
    let textSecondary: Color
    let hairline: Color

    init(theme: ThemeStyle, accent: Color) {
        self.theme = theme
        self.accent = accent
        self.secondary = theme.accentSecondary
        self.backgroundTop = theme.backgroundTop
        self.backgroundBottom = theme.backgroundBottom
        self.surface = Color.white.opacity(0.055)
        self.surfaceRaised = Color.white.opacity(0.085)
        self.textPrimary = Color(hex: 0xF5F8FB)
        self.textSecondary = Color(hex: 0x9AA6B2)
        self.hairline = Color.white.opacity(0.12)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init?(hexString: String) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return nil }
        self.init(hex: hex)
    }

    var hexString: String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case ice = "#70E7FF"
    case ultraviolet = "#A991FF"
    case lime = "#B7FF4C"
    case coral = "#FF526B"
    case cyan = "#39D8FF"
    case amber = "#F0B35E"
    case champagne = "#E8D2A2"
    case rose = "#FF8FBC"

    var id: String { rawValue }
    var color: Color { Color(hexString: rawValue) ?? .white }
}
