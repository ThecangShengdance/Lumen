import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette

    @State private var section: SettingsSection = .appearance
    @State private var confirmsClearShowcase = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AmbientBackground(palette: palette, settings: model.settings)
                Color.black.opacity(0.58)

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 224)

                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 1)

                    VStack(spacing: 0) {
                        settingsHeader
                        Rectangle()
                            .fill(.white.opacity(0.07))
                            .frame(height: 1)
                        ScrollView(showsIndicators: false) {
                            Group {
                                switch section {
                                case .appearance: appearanceSection
                                case .motion: motionSection
                                case .library: librarySection
                                case .about: aboutSection
                                }
                            }
                            .padding(28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 58)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .frame(maxWidth: min(1120, proxy.size.width - 90),
                       maxHeight: min(790, proxy.size.height - 70))
                .background {
                    ZStack {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        Color.black.opacity(0.34)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.65), radius: 60, y: 26)
            }
        }
        .tint(palette.accent)
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .confirmationDialog(
            "清除所有展示内容？",
            isPresented: $confirmsClearShowcase,
            titleVisibility: .visible
        ) {
            Button("清除", role: .destructive) { model.removeShowcaseGames() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会移除 Lumen 自带的三个展示条目，你自己的游戏不会受影响。")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LumenMark(size: 26, showsWordmark: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text("LUMEN")
                        .font(LumenFont.mono(10, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.86))
                    Text("偏好设置")
                        .font(LumenFont.label(8))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 28)

            VStack(spacing: 3) {
                ForEach(SettingsSection.allCases) { item in
                    sidebarItem(item)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.controllerConnected ? palette.accent : .white.opacity(0.2))
                        .frame(width: 5, height: 5)
                    Text(model.controllerConnected ? "手柄已连接" : "键盘 / 触控板")
                        .font(LumenFont.label(8.5))
                        .foregroundStyle(.white.opacity(0.38))
                }
                Text(model.controllerConnected ? model.controllerName : "连接手柄即可使用导航")
                    .font(LumenFont.label(8))
                    .foregroundStyle(.white.opacity(0.24))
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sidebarItem(_ item: SettingsSection) -> some View {
        let active = section == item
        return Button {
            withAnimation(.lumenSnappy) { section = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 17)
                    .foregroundStyle(active ? palette.accent : .white.opacity(0.35))
                Text(item.title)
                    .font(LumenFont.text(11.5, weight: active ? .medium : .regular))
                    .foregroundStyle(active ? .white.opacity(0.9) : .white.opacity(0.46))
                Spacer()
                if active {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 37)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? .white.opacity(0.07) : .clear)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(LumenFont.display(25, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Text(section.subtitle)
                    .font(LumenFont.label(9))
                    .foregroundStyle(.white.opacity(0.34))
            }
            Spacer()
            Text("自动保存")
                .font(LumenFont.label(8.5))
                .foregroundStyle(.white.opacity(0.24))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Capsule().fill(.white.opacity(0.05)))
            IconCircleButton(symbol: "xmark", size: 36, help: "关闭设置") {
                model.closeSettings()
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 78)
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            livePreview

            VStack(alignment: .leading, spacing: 13) {
                settingsLabel("界面风格", note: "一次选择，整套配色、氛围与质感都会随之改变")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                    ForEach(ThemeStyle.allCases) { theme in
                        themeCard(theme)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                settingsLabel("强调色", note: "覆盖当前主题的签名色")
                accentRow
            }

            VStack(alignment: .leading, spacing: 0) {
                settingsLabel("界面细节", note: nil)
                    .padding(.bottom, 10)
                settingsToggle(
                    icon: "circle.grid.cross",
                    title: "胶片颗粒",
                    subtitle: "在背景上叠加细微颗粒，增加电影感",
                    isOn: $model.settings.grainEnabled
                )
                divider
                settingsToggle(
                    icon: "clock",
                    title: "显示时钟",
                    subtitle: "在主页与游戏库顶栏显示当前时间",
                    isOn: $model.settings.clockVisible
                )
                divider
                settingsSlider(
                    icon: "waveform.path",
                    title: "环境光强度",
                    value: $model.settings.ambientIntensity
                )
            }
        }
    }

    private var livePreview: some View {
        let game = model.selectedGame
        return ZStack(alignment: .bottomLeading) {
            if let game {
                GameArtwork(game: game)
                    .frame(maxWidth: .infinity)
                    .frame(height: 146)
                    .clipped()
            } else {
                LinearGradient(colors: [palette.accent.opacity(0.35), palette.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.15), .black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LIVE PREVIEW")
                        .font(LumenFont.label(8))
                        .tracking(2.2)
                        .foregroundStyle(palette.accent.opacity(0.85))
                    Text(game?.title ?? "Lumen")
                        .font(LumenFont.display(24, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(.white.opacity(0.95))
                    Text(game?.tagline ?? "你的私人游戏大厅")
                        .font(LumenFont.text(9.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 7) {
                    Text("开始游戏")
                        .font(LumenFont.text(9.5, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.horizontal, 12)
                        .frame(height: 27)
                        .background(Capsule().fill(.white.opacity(0.9)))
                    Image(systemName: "heart")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 27, height: 27)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
            }
            .padding(16)
        }
        .frame(height: 146)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }

    private func themeCard(_ theme: ThemeStyle) -> some View {
        let active = model.settings.theme == theme
        return Button {
            withAnimation(.lumen) {
                model.settings.theme = theme
                model.settings.customAccentHex = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [theme.backgroundTop, theme.backgroundBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(theme.accent.opacity(0.35))
                        .frame(width: 64, height: 64)
                        .blur(radius: 26)
                        .offset(x: 42, y: 16)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Circle().fill(theme.accent).frame(width: 4, height: 4)
                            Capsule().fill(.white.opacity(0.3)).frame(width: 22, height: 3)
                            Spacer()
                            Capsule().fill(.white.opacity(0.15)).frame(width: 12, height: 3)
                        }
                        Spacer()
                        Capsule()
                            .fill(theme.accent.opacity(0.8))
                            .frame(width: 38, height: 5)
                        Capsule().fill(.white.opacity(0.28)).frame(width: 58, height: 3)
                        Capsule().fill(.white.opacity(0.16)).frame(width: 44, height: 3)
                    }
                    .padding(11)
                }
                .frame(height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(active ? theme.accent.opacity(0.9) : .white.opacity(0.08), lineWidth: active ? 1.6 : 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(theme.name)
                        .font(LumenFont.text(10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(active ? 0.92 : 0.68))
                    Text(theme.chineseName)
                        .font(LumenFont.label(8))
                        .foregroundStyle(.white.opacity(0.32))
                    Spacer()
                    if active {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accent)
                    }
                }
                Text(theme.inspiration)
                    .font(LumenFont.label(8))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(active ? .white.opacity(0.06) : .white.opacity(0.02))
            }
        }
        .buttonStyle(.plain)
    }

    private var accentRow: some View {
        HStack(spacing: 9) {
            Button {
                model.settings.customAccentHex = nil
            } label: {
                ZStack {
                    Circle().fill(palette.accentGradient)
                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    if model.settings.customAccentHex == nil {
                        Circle().strokeBorder(.white, lineWidth: 2).padding(-4)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("跟随主题")

            ForEach(AccentChoice.allCases) { choice in
                Button {
                    model.settings.customAccentHex = choice.rawValue
                } label: {
                    ZStack {
                        Circle().fill(choice.color)
                        if model.settings.customAccentHex == choice.rawValue {
                            Circle().strokeBorder(.white, lineWidth: 2).padding(-4)
                        }
                    }
                    .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help(choice.rawValue)
            }

            ColorPicker(
                "",
                selection: Binding(
                    get: {
                        model.settings.customAccentHex.flatMap(Color.init(hexString:)) ?? model.settings.theme.accent
                    },
                    set: { model.settings.customAccentHex = $0.hexString }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 27, height: 27)
            .help("自定义颜色")

            Spacer()

            Text(model.settings.customAccentHex ?? "跟随主题")
                .font(LumenFont.mono(9))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Motion

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 0) {
                settingsLabel("动效", note: "Lumen 的界面节奏")
                    .padding(.bottom, 10)
                settingsToggle(
                    icon: "sparkles",
                    title: "界面动效",
                    subtitle: "主视觉缓动、悬浮与转场动画",
                    isOn: $model.settings.motionEnabled
                )
                divider
                settingsToggle(
                    icon: "hand.tap",
                    title: "触感反馈",
                    subtitle: "使用触控板时提供轻微震动",
                    isOn: $model.settings.hapticsEnabled
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                settingsLabel("交互说明", note: nil)
                VStack(spacing: 0) {
                    instructionRow(symbol: "keyboard", title: "键盘导航", detail: "方向键移动 · Return 确认 · Esc 返回 · ⌘F 搜索")
                    divider
                    instructionRow(symbol: "gamecontroller", title: "手柄导航", detail: "左摇杆 / 十字键移动 · A 确认 · B 返回 · X 编辑 · Y 收藏")
                    divider
                    instructionRow(symbol: "rectangle.on.rectangle", title: "快速切换", detail: "LB / RB 在主页与游戏库之间切换 · Menu 打开设置")
                    divider
                    instructionRow(symbol: "play.rectangle", title: "启动方式", detail: "Lumen 通过 macOS 打开你指定的 App，不注入、不接管游戏进程")
                }
                .padding(.horizontal, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.025))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
            }
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                statCard(value: "\(model.games.count)", label: "游戏条目", icon: "square.grid.2x2")
                statCard(value: "\(model.installedCount)", label: "可启动", icon: "play.circle")
                statCard(value: "\(model.favoriteCount)", label: "收藏", icon: "heart")
            }

            VStack(alignment: .leading, spacing: 0) {
                settingsLabel("内容管理", note: "展示内容可以随时恢复或清除")
                    .padding(.bottom, 10)
                actionRow(
                    icon: "sparkles",
                    title: "恢复展示游戏",
                    subtitle: "重新加入 Eclipse Protocol、Neon Reverie 与 Verdant"
                ) {
                    model.restoreShowcase()
                }
                divider
                actionRow(
                    icon: "trash",
                    title: "清除展示内容",
                    subtitle: "只移除 Lumen 自带的展示条目",
                    destructive: true
                ) {
                    confirmsClearShowcase = true
                }
                divider
                actionRow(
                    icon: "folder",
                    title: "打开数据目录",
                    subtitle: "游戏库 JSON 与导入的媒体文件"
                ) {
                    model.revealLibraryFolder()
                }
                divider
                actionRow(
                    icon: "paintbrush",
                    title: "恢复默认外观",
                    subtitle: "回到 Aurora 主题与默认强调色"
                ) {
                    withAnimation(.lumen) { model.resetAppearance() }
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(palette.accent.opacity(0.7))
                Text("所有数据仅保存在本机。Lumen 不联网、不上传，也不参与任何游戏的运行。")
                    .font(LumenFont.label(9))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 18) {
                LumenMark(size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Lumen")
                        .font(LumenFont.display(34, weight: .semibold))
                        .tracking(-1)
                        .foregroundStyle(.white.opacity(0.95))
                    Text("Version 1.0.0 · Built for macOS")
                        .font(LumenFont.mono(9))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
            }

            Text("一个安静、克制的游戏启动前端。它不运行游戏，也不修改游戏——只负责把你收藏的世界，以更好的方式呈现在你面前。")
                .font(LumenFont.text(12.5))
                .foregroundStyle(.white.opacity(0.46))
                .lineSpacing(5)
                .frame(maxWidth: 560, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                settingsLabel("设计原则", note: nil)
                    .padding(.bottom, 10)
                aboutRow(symbol: "circle.hexagongrid", title: "沉浸优先", text: "主视觉、环境光与克制的界面元素，让游戏本身成为主角。")
                divider
                aboutRow(symbol: "gamecontroller", title: "沙发友好", text: "完整的手柄导航与清晰的焦点反馈，适合在大屏幕上使用。")
                divider
                aboutRow(symbol: "externaldrive", title: "本地优先", text: "没有账号、没有云同步、没有遥测；你的收藏只属于这台 Mac。")
            }

            Text("Artwork & interface crafted for Lumen Showcase.")
                .font(LumenFont.label(8))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    // MARK: - Building blocks

    private func settingsLabel(_ title: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(LumenFont.text(12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            if let note {
                Text(note)
                    .font(LumenFont.label(8.5))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
    }

    private func settingsToggle(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.accent.opacity(0.72))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LumenFont.text(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                Text(subtitle)
                    .font(LumenFont.label(8.5))
                    .foregroundStyle(.white.opacity(0.28))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(palette.accent)
                .controlSize(.small)
        }
        .padding(.vertical, 11)
    }

    private func settingsSlider(icon: String, title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.accent.opacity(0.72))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.05)))
            Text(title)
                .font(LumenFont.text(11, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
            Slider(value: value, in: 0...1)
                .tint(palette.accent)
                .frame(maxWidth: 200)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(LumenFont.mono(9))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 38, alignment: .trailing)
            Spacer()
        }
        .padding(.vertical, 11)
    }

    private func instructionRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 20)
            Text(title)
                .font(LumenFont.text(10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 76, alignment: .leading)
            Text(detail)
                .font(LumenFont.label(8.5))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(destructive ? Color(hex: 0xFF8B7A).opacity(0.8) : palette.accent.opacity(0.72))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.05)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LumenFont.text(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))
                    Text(subtitle)
                        .font(LumenFont.label(8.5))
                        .foregroundStyle(.white.opacity(0.28))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(palette.accent.opacity(0.65))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(LumenFont.display(20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(label)
                    .font(LumenFont.label(8))
                    .foregroundStyle(.white.opacity(0.28))
            }
            Spacer()
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func aboutRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.accent.opacity(0.65))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(LumenFont.text(10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                Text(text)
                    .font(LumenFont.label(9))
                    .foregroundStyle(.white.opacity(0.29))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 11)
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance
    case motion
    case library
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: "外观"
        case .motion: "动效与交互"
        case .library: "游戏库"
        case .about: "关于 Lumen"
        }
    }

    var subtitle: String {
        switch self {
        case .appearance: "风格、配色、颗粒与时钟"
        case .motion: "动画、触感与操作方式"
        case .library: "内容、素材与数据目录"
        case .about: "版本、原则与致谢"
        }
    }

    var icon: String {
        switch self {
        case .appearance: "paintpalette"
        case .motion: "sparkles"
        case .library: "square.grid.2x2"
        case .about: "info.circle"
        }
    }
}
