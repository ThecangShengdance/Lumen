import AVKit
import AppKit
import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette
    @State private var confirmsDelete = false

    var body: some View {
        if let game = model.detailGame {
            GeometryReader { proxy in
                ZStack {
                    background(game: game, size: proxy.size)

                    VStack(spacing: 0) {
                        topBar
                        Spacer(minLength: 10)
                        content(game: game, wide: proxy.size.width > 1260)
                            .padding(.horizontal, 54)
                            .padding(.bottom, 30)
                    }
                    .padding(.top, 20)

                    if model.isTrailerPresented, let path = game.trailerPath {
                        TrailerPlayerOverlay(
                            title: game.title,
                            url: URL(fileURLWithPath: path),
                            onClose: { withAnimation(.lumen) { model.isTrailerPresented = false } }
                        )
                        .transition(.opacity)
                        .zIndex(10)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .confirmationDialog(
                "从游戏库移除「\(game.title)」？",
                isPresented: $confirmsDelete,
                titleVisibility: .visible
            ) {
                Button("移除", role: .destructive) {
                    model.deleteGame(game)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会移除 Lumen 中的条目与已导入的素材，不会删除游戏 App 本身。")
            }
        }
    }

    // MARK: - Background

    private func background(game: Game, size: CGSize) -> some View {
        let accent = game.accent(using: palette)
        return ZStack {
            GameArtwork(game: game)
                .frame(width: size.width * 1.03, height: size.height * 1.03)
                .blur(radius: 2)
                .id(game.id)
                .transition(.opacity)

            Color.black.opacity(0.32)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.64), location: 0),
                    .init(color: .black.opacity(0.16), location: 0.38),
                    .init(color: .black.opacity(0.66), location: 0.8),
                    .init(color: .black.opacity(0.95), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.65), location: 0),
                    .init(color: .clear, location: 0.55)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [accent.opacity(0.24), .clear],
                center: UnitPoint(x: 0.2, y: 0.72),
                startRadius: 0,
                endRadius: size.width * 0.4
            )
            .blendMode(.screen)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            LumenMark(size: 26)
            Text("游戏详情")
                .font(LumenFont.label(10))
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.38))
            Spacer()
            HStack(spacing: 8) {
                if model.detailGame?.trailerPath != nil {
                    KeyHint(key: "menu", label: "宣传片")
                }
                KeyHint(key: "esc", label: "关闭")
                IconCircleButton(symbol: "xmark", size: 38, help: "关闭") {
                    model.closeDetail()
                }
            }
        }
        .padding(.horizontal, 34)
    }

    // MARK: - Content

    private func content(game: Game, wide: Bool) -> some View {
        let accent = game.accent(using: palette)
        return HStack(alignment: .bottom, spacing: wide ? 34 : 24) {
            PosterArtwork(game: game)
                .frame(width: wide ? 196 : 168, height: wide ? 294 : 252)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.55), radius: 30, y: 18)

            VStack(alignment: .leading, spacing: 0) {
                SectionEyebrow(
                    text: game.isShowcase ? "Lumen Showcase" : "Installed Game",
                    accent: accent
                )
                .padding(.bottom, 10)

                Text(game.title)
                    .font(LumenFont.display(wide ? 52 : 42, weight: .semibold))
                    .tracking(-1.5)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .padding(.bottom, 5)

                if !game.tagline.isEmpty {
                    Text(game.tagline)
                        .font(LumenFont.text(14.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                        .padding(.bottom, 12)
                }

                Text(game.overview)
                    .font(LumenFont.text(12.6))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineSpacing(4.5)
                    .lineLimit(5)
                    .frame(maxWidth: 590, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(metadata(game), id: \.self) { item in
                        MetaPill(text: item, tint: accent)
                    }
                }
                .padding(.top, 16)

                if !game.hasPlayableApp {
                    HStack(spacing: 7) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text(game.isShowcase
                             ? "展示内容仅用于预览，绑定你自己的游戏 App 后即可从这里启动。"
                             : "尚未绑定启动路径，点击「绑定游戏 App」选择游戏 App。")
                    }
                    .font(LumenFont.text(10.5))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.top, 12)
                }

                HStack(spacing: 11) {
                    LumenActionButton(
                        title: game.hasPlayableApp ? "开始游戏" : "绑定游戏 App",
                        symbol: game.hasPlayableApp ? "play.fill" : "link.badge.plus",
                        style: .primary
                    ) {
                        model.launch(game)
                    }

                    if let trailer = game.trailerPath,
                       FileManager.default.fileExists(atPath: trailer) {
                        LumenActionButton(title: "宣传片", symbol: "play.rectangle", style: .secondary) {
                            withAnimation(.lumen) { model.isTrailerPresented = true }
                        }
                    }

                    LumenActionButton(title: "编辑", symbol: "slider.horizontal.3", style: .secondary) {
                        model.presentEditor(for: game)
                    }

                    IconCircleButton(
                        symbol: game.isFavorite ? "heart.fill" : "heart",
                        size: 44,
                        isActive: game.isFavorite,
                        help: game.isFavorite ? "取消收藏" : "加入收藏"
                    ) {
                        model.toggleFavorite(game)
                    }
                }
                .padding(.top, 20)
            }

            Spacer(minLength: 8)

            if wide {
                infoPanel(game: game)
                    .frame(width: 252)
                    .padding(.bottom, 2)
            }
        }
    }

    private func metadata(_ game: Game) -> [String] {
        [game.releaseYear, game.genre, game.developer]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func infoPanel(game: Game) -> some View {
        GlassPanel(radius: 22, padding: 20, tint: .white) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("游戏信息")
                        .font(LumenFont.label(10))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Button {
                        confirmsDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help("从游戏库移除")
                }
                .padding(.bottom, 14)

                infoRow("开发商", game.developer, accent: palette.accent)
                infoRow("发行商", game.publisher, accent: palette.accent)
                infoRow("版本", game.version, accent: palette.accent)
                infoRow("上次启动", game.lastPlayedLabel, accent: palette.accent)

                if game.launchCount > 0 {
                    infoRow("启动次数", "\(game.launchCount)", accent: palette.accent)
                }

                Divider()
                    .overlay(.white.opacity(0.1))
                    .padding(.vertical, 12)

                Button {
                    if game.hasPlayableApp {
                        model.reveal(game)
                    } else {
                        model.presentEditor(for: game)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: game.hasPlayableApp ? "folder" : "link.badge.plus")
                        Text(game.hasPlayableApp ? "在 Finder 中显示" : "选择启动路径")
                        Spacer()
                    }
                    .font(LumenFont.text(10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, accent: Color) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(LumenFont.label(9.5))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 56, alignment: .leading)
            Text(trimmed.isEmpty ? "—" : trimmed)
                .font(LumenFont.text(10.8, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Trailer

private struct TrailerPlayerOverlay: View {
    let title: String
    let url: URL
    var onClose: () -> Void

    @State private var player: AVPlayer
    @Environment(\.lumenPalette) private var palette

    init(title: String, url: URL, onClose: @escaping () -> Void) {
        self.title = title
        self.url = url
        self.onClose = onClose
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(palette.accent)
                        Text("\(title) · 宣传片")
                            .font(LumenFont.text(13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)

                TrailerPlayerView(player: player)
                    .frame(maxWidth: 1120, maxHeight: 660)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
            }
            .padding(30)
            .frame(maxWidth: 1200)
        }
        .onAppear { player.play() }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
}


// AVKit's SwiftUI VideoPlayer can abort during Swift metadata initialization on
// newer macOS builds. AVPlayerView is the stable AppKit path and keeps native controls.
private struct TrailerPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = true
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}
