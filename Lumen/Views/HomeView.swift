import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette
    @State private var heroScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            if let game = model.selectedGame {
                let compact = proxy.size.height < 830
                ZStack(alignment: .bottomLeading) {
                    heroBackdrop(game: game, size: proxy.size)

                    if proxy.size.width > 1320 {
                        indexRail(game: game, size: proxy.size)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: compact ? 68 : 96)
                        heroInfo(game: game, compact: compact)
                        actionRow(game: game)
                            .padding(.top, compact ? 18 : 24)
                        shelf(compact: compact)
                            .padding(.top, compact ? 16 : 28)
                        footer
                            .padding(.top, compact ? 8 : 12)
                    }
                    .padding(.leading, 58)
                    .padding(.trailing, 48)
                    .padding(.top, compact ? 72 : 84)
                    .padding(.bottom, 12)
                }
                .onAppear { startKenBurns() }
                .onChange(of: model.selectedGameID) { _ in
                    withAnimation(.easeInOut(duration: 0.7)) {
                        heroScale = 1.0
                    }
                    startKenBurns()
                }
            } else {
                EmptyLibraryView(
                    title: "游戏库还是空的",
                    message: "导入一个 macOS 游戏 App，添加你自己的主视觉、图标与宣传片。",
                    action: { LumenPanels.importGame(into: model) }
                )
                .padding(.top, 80)
            }
        }
    }

    // MARK: - Hero

    private func heroBackdrop(game: Game, size: CGSize) -> some View {
        let accent = game.accent(using: palette)
        return ZStack {
            GameArtwork(game: game)
                .frame(width: size.width * 1.04, height: size.height * 1.04)
                .scaleEffect(model.settings.motionEnabled ? heroScale : 1.0)
                .id(game.id)
                .transition(.opacity)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.78), location: 0),
                    .init(color: .black.opacity(0.42), location: 0.30),
                    .init(color: .black.opacity(0.05), location: 0.62),
                    .init(color: .clear, location: 0.78)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.34),
                    .init(color: .black.opacity(0.30), location: 0.63),
                    .init(color: .black.opacity(0.90), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [accent.opacity(0.22), .clear],
                center: UnitPoint(x: 0.16, y: 0.80),
                startRadius: 0,
                endRadius: size.width * 0.42
            )
            .blendMode(.screen)
            .allowsHitTesting(false)

            LinearGradient(
                colors: [.black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 190)
            .frame(maxHeight: .infinity, alignment: .top)

            Color.black.opacity(0.06)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .animation(.easeInOut(duration: 0.75), value: game.id)
    }

    private func startKenBurns() {
        guard model.settings.motionEnabled else { return }
        withAnimation(.easeInOut(duration: 16)) {
            heroScale = 1.075
        }
    }

    private func indexRail(game: Game, size: CGSize) -> some View {
        let index = (model.sortedGames.firstIndex(where: { $0.id == game.id }) ?? 0) + 1
        return VStack(alignment: .trailing, spacing: 10) {
            Text(String(format: "%02d", index))
                .font(LumenFont.display(52, weight: .light))
                .foregroundStyle(.white.opacity(0.24))
                .monospacedDigit()
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.34), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1, height: 54)
            Text("OF \(String(format: "%02d", model.games.count))")
                .font(LumenFont.mono(9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.28))
        }
        .position(x: size.width - 72, y: size.height * 0.42)
        .allowsHitTesting(false)
    }

    private func heroInfo(game: Game, compact: Bool) -> some View {
        let accent = game.accent(using: palette)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SectionEyebrow(
                    text: game.isShowcase ? "Lumen Showcase" : (game.isFavorite ? "Favorite" : "Your Collection"),
                    accent: accent
                )
                if game.isShowcase {
                    MetaPill(text: "展示内容", tint: accent)
                } else if game.hasPlayableApp {
                    MetaPill(text: "已安装", symbol: "checkmark", tint: accent)
                }
            }
            .padding(.bottom, compact ? 12 : 16)

            Text(game.title)
                .font(LumenFont.display(compact ? 46 : 68, weight: .semibold))
                .tracking(-1.8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 6)

            if !game.tagline.isEmpty {
                Text(game.tagline)
                    .font(LumenFont.text(compact ? 14.5 : 16.5, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, compact ? 2 : 4)
            }

            Text(game.overview)
                .font(LumenFont.text(compact ? 12 : 13.2))
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(compact ? 3 : 4.5)
                .lineLimit(compact ? 2 : 3)
                .frame(maxWidth: compact ? 500 : 560, alignment: .leading)
                .padding(.top, compact ? 10 : 14)

            HStack(spacing: 10) {
                ForEach(metadata(for: game), id: \.self) { item in
                    Text(item)
                        .font(LumenFont.label(10.5))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.46))
                    if item != metadata(for: game).last {
                        Circle()
                            .fill(.white.opacity(0.26))
                            .frame(width: 3, height: 3)
                    }
                }
                if !game.hasPlayableApp {
                    MetaPill(text: "未绑定 App", symbol: "link.badge.plus", tint: .white.opacity(0.8))
                        .padding(.leading, 2)
                }
            }
            .padding(.top, compact ? 10 : 14)
        }
    }

    private func metadata(for game: Game) -> [String] {
        [game.releaseYear, game.genre, game.developer]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func actionRow(game: Game) -> some View {
        HStack(spacing: 12) {
            LumenActionButton(
                title: game.hasPlayableApp ? "开始游戏" : "绑定游戏",
                symbol: game.hasPlayableApp ? "play.fill" : "link.badge.plus",
                style: .primary,
                isFocused: model.homeFocus == .actions && model.actionIndex == 0
            ) {
                model.launch(game)
            }

            LumenActionButton(
                title: "详情",
                symbol: "info.circle",
                style: .secondary,
                isFocused: model.homeFocus == .actions && model.actionIndex == 1
            ) {
                model.openDetail(for: game)
            }

            LumenActionButton(
                title: "编辑",
                symbol: "slider.horizontal.3",
                style: .quiet,
                isFocused: model.homeFocus == .actions && model.actionIndex == 2
            ) {
                model.presentEditor(for: game)
            }

            IconCircleButton(
                symbol: game.isFavorite ? "heart.fill" : "heart",
                size: 42,
                isActive: game.isFavorite,
                help: game.isFavorite ? "取消收藏" : "加入收藏"
            ) {
                model.toggleFavorite(game)
            }
            .padding(.leading, 2)

            Spacer()

            if !game.hasPlayableApp {
                Text("绑定 App 后即可从这里直接启动")
                    .font(LumenFont.text(10.5))
                    .foregroundStyle(.white.opacity(0.34))
            }
        }
    }

    // MARK: - Shelf

    private func shelf(compact: Bool) -> some View {
        let cardWidth: CGFloat = compact ? 220 : 286
        let imageHeight = cardWidth * 9 / 16

        return VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack(spacing: 10) {
                Text("游戏库")
                    .font(LumenFont.text(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(model.games.count)")
                    .font(LumenFont.mono(9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.34))
                Spacer()
                Button {
                    model.selectTab(.library)
                } label: {
                    HStack(spacing: 5) {
                        Text("查看全部")
                            .font(LumenFont.text(10.5, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.44))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 8)

            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(model.sortedGames) { game in
                            HomeShelfCard(
                                game: game,
                                isSelected: model.selectedGame?.id == game.id,
                                width: cardWidth,
                                imageHeight: imageHeight
                            ) {
                                model.select(game.id)
                            } onOpen: {
                                model.openDetail(for: game)
                            } onLaunch: {
                                model.launch(game)
                            } onToggleFavorite: {
                                model.toggleFavorite(game)
                            }
                            .id(game.id)
                        }

                        AddGameCard(height: imageHeight) {
                            LumenPanels.importGame(into: model)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
                }
                .frame(height: imageHeight + 10)
                .onChange(of: model.selectedGameID) { id in
                    guard let id else { return }
                    withAnimation(.lumenSnappy) {
                        reader.scrollTo(id, anchor: .center)
                    }
                }
                .onAppear {
                    if let id = model.selectedGame?.id {
                        reader.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            ControlHints()
            Spacer()
            Text("LUMEN  ·  v1.0")
                .font(LumenFont.mono(9, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.trailing, 8)
    }
}

// MARK: - Shelf card

private struct HomeShelfCard: View {
    let game: Game
    let isSelected: Bool
    let width: CGFloat
    let imageHeight: CGFloat
    var onSelect: () -> Void
    var onOpen: () -> Void
    var onLaunch: () -> Void
    var onToggleFavorite: () -> Void

    @Environment(\.lumenPalette) private var palette
    @State private var hovering = false

    private var accent: Color { game.accent(using: palette) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GameArtwork(game: game)
                .frame(width: width, height: imageHeight)

            LinearGradient(
                colors: [.clear, .black.opacity(0.18), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .top) {
                GameIcon(game: game, size: 28, showsGlow: false)
                Spacer()
                if game.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(accent)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.38)))
                }
            }
            .padding(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(LumenFont.text(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                Text(game.isShowcase ? "展示内容" : game.genre)
                    .font(LumenFont.label(8.5))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.44))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .padding(.trailing, 30)

            if isSelected {
                HStack(spacing: 4) {
                    Image(systemName: game.hasPlayableApp ? "play.fill" : "link")
                        .font(.system(size: 8, weight: .bold))
                    Text(game.hasPlayableApp ? "启动" : "绑定")
                        .font(LumenFont.label(8))
                }
                .foregroundStyle(.black.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(accent.opacity(0.92)))
                .padding(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: width, height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? accent.opacity(0.92) : .white.opacity(hovering ? 0.2 : 0.09),
                    lineWidth: isSelected ? 1.8 : 1
                )
        }
        .shadow(
            color: isSelected ? accent.opacity(0.28) : .black.opacity(0.3),
            radius: isSelected ? 22 : 10,
            y: isSelected ? 10 : 6
        )
        .scaleEffect(isSelected ? 1.025 : (hovering ? 1.012 : 1))
        .opacity(isSelected ? 1 : (hovering ? 0.94 : 0.78))
        .animation(.lumenSnappy, value: isSelected)
        .animation(.easeOut(duration: 0.18), value: hovering)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { value in hovering = value }
        .onTapGesture(count: 2) { onOpen() }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("开始游戏") { onSelect(); onLaunch() }
            Button("查看详情") { onSelect(); onOpen() }
            Divider()
            Button(game.isFavorite ? "取消收藏" : "加入收藏") {
                onSelect(); onToggleFavorite()
            }
        }
        .accessibilityLabel(game.title)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}

private struct AddGameCard: View {
    let height: CGFloat
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .light))
                Text("导入游戏")
                    .font(LumenFont.text(10.5, weight: .medium))
            }
            .foregroundStyle(.white.opacity(hovering ? 0.82 : 0.42))
            .frame(width: height * 1.05, height: height)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.05 : 0.02))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        .white.opacity(hovering ? 0.26 : 0.13),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.16)) { hovering = value }
        }
    }
}
