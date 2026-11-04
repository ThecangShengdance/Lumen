import AppKit
import SwiftUI

// MARK: - Artwork

struct GameArtwork: View {
    let game: Game
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = ArtworkCache.shared.image(at: game.heroPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                FallbackArtwork(game: game, compact: contentMode == .fill)
            }
        }
        .clipped()
    }
}

struct PosterArtwork: View {
    let game: Game

    var body: some View {
        Group {
            if let image = ArtworkCache.shared.image(at: game.posterPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let image = ArtworkCache.shared.image(at: game.heroPath) {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.08), .black.opacity(0.62)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            game.accent(using: AppSettings().palette).opacity(0.55),
                            Color(hex: 0x090B10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(game.title)
                            .font(LumenFont.display(20))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                }
            }
        }
        .clipped()
    }
}

struct FallbackArtwork: View {
    let game: Game
    var compact = false

    private var accent: Color {
        game.accent(using: AppSettings().palette)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.42), Color(hex: 0x07090D), Color(hex: 0x030405)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            GeometryReader { proxy in
                let side = max(proxy.size.width, proxy.size.height)
                Circle()
                    .strokeBorder(accent.opacity(0.24), lineWidth: 1)
                    .frame(width: side * 0.62, height: side * 0.62)
                    .position(x: proxy.size.width * 0.7, y: proxy.size.height * 0.3)
                Circle()
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                    .frame(width: side * 0.92, height: side * 0.92)
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.2)
            }

            VStack(spacing: compact ? 8 : 18) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: compact ? 26 : 46, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.42))
                if !compact {
                    Text(game.title)
                        .font(LumenFont.display(40))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

struct GameIcon: View {
    let game: Game
    var size: CGFloat = 52
    var showsGlow = false

    private var accent: Color {
        game.accent(using: AppSettings().palette)
    }

    var body: some View {
        Group {
            if let image = ArtworkCache.shared.image(at: game.iconPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [accent.opacity(0.65), Color(hex: 0x0B0D12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(String(game.title.prefix(1)).uppercased())
                        .font(LumenFont.display(size * 0.4))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: showsGlow ? accent.opacity(0.35) : .black.opacity(0.25), radius: showsGlow ? 18 : 8, y: 6)
    }
}

// MARK: - Pills & labels

struct MetaPill: View {
    var text: String
    var symbol: String?
    var tint: Color = .white
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(LumenFont.label(11))
                .tracking(0.4)
        }
        .foregroundStyle(filled ? Color.black : tint.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(filled ? tint.opacity(0.92) : Color.white.opacity(0.07))
        }
        .overlay {
            if !filled {
                Capsule().strokeBorder(.white.opacity(0.11), lineWidth: 0.8)
            }
        }
    }
}

struct SectionEyebrow: View {
    var text: String
    var accent: Color

    var body: some View {
        HStack(spacing: 9) {
            Rectangle()
                .fill(accent)
                .frame(width: 18, height: 2)
            Text(text.uppercased())
                .font(LumenFont.label(10))
                .tracking(2.6)
                .foregroundStyle(accent.opacity(0.92))
        }
    }
}

// MARK: - Buttons

enum LumenActionStyle {
    case primary
    case secondary
    case quiet
}

struct LumenActionButton: View {
    var title: String
    var symbol: String
    var style: LumenActionStyle = .primary
    var isFocused: Bool = false
    var action: () -> Void

    @Environment(\.lumenPalette) private var palette
    @State private var hovering = false

    private var foreground: Color {
        switch style {
        case .primary: return .black.opacity(0.86)
        case .secondary, .quiet: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(LumenFont.text(14, weight: .semibold))
                    .tracking(0.2)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, style == .quiet ? 14 : 22)
            .frame(height: 44)
            .background {
                ZStack {
                    switch style {
                    case .primary:
                        Capsule().fill(Color.white.opacity(hovering ? 1 : 0.92))
                    case .secondary:
                        Capsule().fill(Color.white.opacity(hovering ? 0.15 : 0.09))
                        Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    case .quiet:
                        Capsule().fill(Color.white.opacity(hovering ? 0.09 : 0.001))
                    }
                }
            }
            .overlay {
                if isFocused {
                    Capsule()
                        .strokeBorder(palette.accent.opacity(0.95), lineWidth: 1.6)
                        .padding(-4)
                        .shadow(color: palette.accent.opacity(0.55), radius: 12)
                }
            }
            .scaleEffect(hovering ? 1.018 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.lumenSnappy) { hovering = value }
        }
    }
}

struct IconCircleButton: View {
    var symbol: String
    var size: CGFloat = 38
    var isActive: Bool = false
    var help: String = ""
    var action: () -> Void

    @Environment(\.lumenPalette) private var palette
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(isActive ? palette.accent : .white.opacity(hovering ? 0.96 : 0.68))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.white.opacity(hovering ? 0.11 : 0.045))
                    Circle()
                        .strokeBorder(.white.opacity(isActive ? 0.2 : 0.08), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { value in
            withAnimation(.lumenSnappy) { hovering = value }
        }
    }
}

struct WindowButton: View {
    enum Kind {
        case close, minimize, zoom
        var color: Color {
            switch self {
            case .close: Color(hex: 0xFF5F57)
            case .minimize: Color(hex: 0xFEBC2E)
            case .zoom: Color(hex: 0x28C840)
            }
        }
        var symbol: String {
            switch self {
            case .close: "xmark"
            case .minimize: "minus"
            case .zoom: "arrow.up.left.and.arrow.down.right"
            }
        }
    }

    let kind: Kind
    @State private var hovering = false

    var body: some View {
        Button {
            guard let window = NSApp.keyWindow else { return }
            switch kind {
            case .close: window.performClose(nil)
            case .minimize: window.miniaturize(nil)
            case .zoom: window.toggleFullScreen(nil)
            }
        } label: {
            ZStack {
                Circle().fill(kind.color.opacity(hovering ? 1 : 0.85))
                if hovering {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .frame(width: 11, height: 11)
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.12)) { hovering = value }
        }
    }
}

struct WindowControls: View {
    var body: some View {
        HStack(spacing: 8) {
            WindowButton(kind: .close)
            WindowButton(kind: .minimize)
            WindowButton(kind: .zoom)
        }
        .padding(.trailing, 4)
    }
}

// MARK: - Top bar

struct LumenTopBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette
    @Namespace private var tabNamespace
    @State private var searchExpanded = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 22) {
            WindowControls()

            LumenMark(size: 28)
                .padding(.leading, 6)

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(width: 1, height: 18)
                .padding(.horizontal, 2)

            HStack(spacing: 6) {
                ForEach(AppTab.allCases) { item in
                    tabButton(item)
                }
            }

            Spacer(minLength: 10)

            if model.tab == .library {
                searchField
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                IconCircleButton(
                    symbol: "plus",
                    size: 36,
                    help: "导入游戏（⌘O）"
                ) {
                    LumenPanels.importGame(into: model)
                }

                IconCircleButton(
                    symbol: "slider.horizontal.3",
                    size: 36,
                    isActive: model.isSettingsPresented,
                    help: "设置（⌘,）"
                ) {
                    model.presentSettings()
                }
            }

            ClockView()
                .padding(.leading, 4)

            ControllerBadge()
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .onChange(of: model.focusSearchToken) { _ in
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: model.tab) { newTab in
            if newTab != .library { searchFocused = false }
        }
        .background {
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            model.selectTab(tab)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 4, height: 4)
                    .opacity(model.tab == tab ? 1 : 0)
                Text(tab.title)
                    .font(LumenFont.text(13, weight: .medium))
                    .tracking(0.6)
            }
                .foregroundStyle(model.tab == tab ? Color.white : Color.white.opacity(0.46))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background {
                    if model.tab == tab {
                        Capsule()
                            .fill(.white.opacity(0.085))
                            .matchedGeometryEffect(id: "tab", in: tabNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
            TextField("搜索游戏", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(LumenFont.text(12.5))
                .focused($searchFocused)
                .frame(width: 132)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background {
            Capsule().fill(.white.opacity(0.06))
            Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }
}

struct ClockView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.settings.clockVisible {
            TimelineView(.periodic(from: .now, by: 20)) { context in
                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(LumenFont.mono(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .monospacedDigit()
            }
            .transition(.opacity)
        }
    }
}

struct ControllerBadge: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: model.controllerConnected ? "gamecontroller.fill" : "keyboard")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.controllerConnected ? palette.accent : .white.opacity(0.35))

            if model.controllerConnected {
                if let battery = model.controllerBattery, battery >= 0 {
                    BatteryGlyph(level: battery, tint: palette.accent)
                } else {
                    Text("已连接")
                        .font(LumenFont.label(10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text("键盘")
                    .font(LumenFont.label(10))
                    .foregroundStyle(.white.opacity(0.32))
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background {
            Capsule().fill(.white.opacity(0.045))
            Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .help(model.controllerName.isEmpty ? "未连接手柄" : model.controllerName)
    }
}

struct BatteryGlyph: View {
    let level: Float
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 20, height: 10)
                RoundedRectangle(cornerRadius: 1.4)
                    .fill(level < 0.2 ? Color(hex: 0xFF5F57) : tint)
                    .frame(width: max(2, CGFloat(level) * 17), height: 6)
                    .padding(.leading, 1.6)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.35))
                .frame(width: 2, height: 4)
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: LumenToast
    @Environment(\.lumenPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.accent)
            Text(toast.text)
                .font(LumenFont.text(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Empty state

struct EmptyLibraryView: View {
    var title: String
    var message: String
    var buttonTitle: String = "导入游戏"
    var action: () -> Void

    @Environment(\.lumenPalette) private var palette

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.08))
                    .frame(width: 104, height: 104)
                Circle()
                    .strokeBorder(palette.accent.opacity(0.22), lineWidth: 1)
                    .frame(width: 104, height: 104)
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(palette.accent.opacity(0.85))
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(LumenFont.display(26))
                    .foregroundStyle(.white.opacity(0.92))
                Text(message)
                    .font(LumenFont.text(13))
                    .foregroundStyle(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .lineSpacing(4)
            }

            LumenActionButton(title: buttonTitle, symbol: "plus", style: .secondary, action: action)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Key hints

struct KeyHint: View {
    var key: String
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(LumenFont.label(9))
                .foregroundStyle(.white.opacity(0.84))
                .frame(minWidth: 20, minHeight: 20)
                .padding(.horizontal, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white.opacity(0.11))
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
            Text(label)
                .font(LumenFont.text(10.5))
                .foregroundStyle(.white.opacity(0.38))
        }
    }
}

struct ControlHints: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            if model.controllerConnected {
                KeyHint(key: "✕", label: "选择")
                KeyHint(key: "○", label: "返回")
                KeyHint(key: "△", label: "收藏")
                KeyHint(key: "☰", label: "设置")
            } else {
                KeyHint(key: "↩", label: "选择")
                KeyHint(key: "esc", label: "返回")
                KeyHint(key: "F", label: "收藏")
                KeyHint(key: "⌘,", label: "设置")
            }
        }
        .padding(.horizontal, 4)
    }
}
