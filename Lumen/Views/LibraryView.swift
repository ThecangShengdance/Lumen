import AppKit
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let columnCount = max(2, min(5, Int((proxy.size.width - 55) / 300)))
            let columns = Array(
                repeating: GridItem(.flexible(minimum: 190), spacing: 18),
                count: columnCount
            )

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 58)
                    .padding(.top, 102)

                filterRow
                    .padding(.horizontal, 58)
                    .padding(.top, 22)
                    .padding(.bottom, 20)

                if model.libraryGames.isEmpty {
                    if model.games.isEmpty {
                        EmptyLibraryView(
                            title: "还没有游戏",
                            message: "导入一个 macOS 游戏 App，Lumen 会在这里为它留出位置。",
                            action: { LumenPanels.importGame(into: model) }
                        )
                    } else {
                        EmptySearchView(query: model.searchText)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 22) {
                            ForEach(model.libraryGames) { game in
                                LibraryCard(game: game)
                                    .id(game.id)
                            }
                            if model.libraryGames.count % columnCount != 0 {
                                AddLibraryTile()
                            }
                        }
                        .padding(.horizontal, 58)
                        .padding(.top, 2)
                        .padding(.bottom, 46)
                    }
                }

                Spacer(minLength: 0)

                libraryFooter
                    .padding(.horizontal, 58)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { model.libraryColumns = columnCount }
            .onChange(of: columnCount) { count in model.libraryColumns = count }
            .onChange(of: model.libraryFilter) { _ in ensureSelection() }
            .onChange(of: model.searchText) { _ in ensureSelection() }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 9) {
                SectionEyebrow(text: "Your Library", accent: palette.accent)
                Text("游戏库")
                    .font(LumenFont.display(46, weight: .semibold))
                    .tracking(-1.2)
                    .foregroundStyle(.white.opacity(0.94))
                HStack(spacing: 8) {
                    Text("\(model.games.count) 个条目")
                    Circle().fill(.white.opacity(0.25)).frame(width: 3, height: 3)
                    Text("\(model.installedCount) 个可启动")
                    Circle().fill(.white.opacity(0.25)).frame(width: 3, height: 3)
                    Text("\(model.favoriteCount) 个收藏")
                }
                .font(LumenFont.label(10.5))
                .foregroundStyle(.white.opacity(0.38))
            }

            Spacer()

            HStack(spacing: 10) {
                LumenActionButton(
                    title: "导入游戏",
                    symbol: "plus",
                    style: .primary
                ) {
                    LumenPanels.importGame(into: model)
                }
                IconCircleButton(symbol: "folder", size: 42, help: "打开数据目录") {
                    model.revealLibraryFolder()
                }
            }
        }
    }

    private var libraryFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .font(.system(size: 11, weight: .regular))
            Text("把游戏 .app 拖进窗口即可添加")
            Circle().fill(.white.opacity(0.18)).frame(width: 3, height: 3)
            Text("双击卡片查看详情")
            Spacer()
            Text("LUMEN LIBRARY")
                .font(LumenFont.mono(8.5, weight: .medium))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.18))
        }
        .font(LumenFont.label(9.5))
        .foregroundStyle(.white.opacity(0.3))
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(LibraryFilter.allCases) { filter in
                filterChip(filter)
            }
            Spacer()
            if !model.searchText.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                    Text("“\(model.searchText)”")
                }
                .font(LumenFont.label(10))
                .foregroundStyle(.white.opacity(0.36))
                .lineLimit(1)
                .frame(maxWidth: 220, alignment: .trailing)
            }
        }
    }

    private func filterChip(_ filter: LibraryFilter) -> some View {
        let count: Int
        switch filter {
        case .all: count = model.games.count
        case .favorites: count = model.favoriteCount
        case .recent: count = model.games.filter { $0.lastPlayedAt != nil }.count
        }
        let active = model.libraryFilter == filter

        return Button {
            withAnimation(.lumenSnappy) { model.libraryFilter = filter }
        } label: {
            HStack(spacing: 7) {
                Text(filter.title)
                Text("\(count)")
                    .font(LumenFont.mono(8.5, weight: .semibold))
                    .opacity(active ? 0.55 : 0.38)
            }
            .font(LumenFont.text(11.5, weight: .medium))
            .foregroundStyle(active ? Color.black.opacity(0.82) : Color.white.opacity(0.52))
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background {
                Capsule()
                    .fill(active ? Color.white.opacity(0.9) : Color.white.opacity(0.05))
            }
            .overlay {
                if !active {
                    Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func ensureSelection() {
        let list = model.libraryGames
        guard !list.isEmpty else { return }
        if !list.contains(where: { $0.id == model.selectedGameID }) {
            model.selectedGameID = list.first?.id
        }
    }
}

// MARK: - Grid card

private struct LibraryCard: View {
    let game: Game
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette
    @State private var hovering = false

    private var isSelected: Bool { model.selectedGame?.id == game.id }
    private var accent: Color { game.accent(using: palette) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                GameArtwork(game: game)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 184)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.12), .black.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .top) {
                    GameIcon(game: game, size: 30)
                    Spacer()
                    HStack(spacing: 5) {
                        if game.isShowcase {
                            MetaPill(text: "展示", tint: .white.opacity(0.85))
                        }
                        if game.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accent)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(LumenFont.text(15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(game.genre)
                        if !game.releaseYear.isEmpty {
                            Circle().fill(.white.opacity(0.24)).frame(width: 2.5, height: 2.5)
                            Text(game.releaseYear)
                        }
                        if !game.hasPlayableApp {
                            Text("未绑定")
                                .foregroundStyle(accent.opacity(0.8))
                        }
                    }
                    .font(LumenFont.label(8.5))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

                if isSelected {
                    Circle()
                        .fill(accent.opacity(0.94))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black.opacity(0.72))
                                .offset(x: 1)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 184)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent.opacity(0.92) : .white.opacity(hovering ? 0.18 : 0.08),
                        lineWidth: isSelected ? 1.8 : 1
                    )
            }
            .shadow(
                color: isSelected ? accent.opacity(0.26) : .black.opacity(0.28),
                radius: isSelected ? 20 : (hovering ? 14 : 8),
                y: isSelected ? 9 : 5
            )
            .scaleEffect(isSelected ? 1.018 : (hovering ? 1.009 : 1))
            .animation(.lumenSnappy, value: isSelected)
            .animation(.easeOut(duration: 0.18), value: hovering)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { value in hovering = value }
        .onTapGesture(count: 2) {
            model.select(game.id)
            model.openDetail(for: game)
        }
        .onTapGesture { model.select(game.id) }
        .contextMenu {
            Button("开始游戏") { model.launch(game) }
            Button("查看详情") { model.select(game.id); model.openDetail(for: game) }
            Button("编辑信息") { model.select(game.id); model.presentEditor(for: game) }
            Divider()
            Button(game.isFavorite ? "取消收藏" : "加入收藏") { model.toggleFavorite(game) }
            if game.hasPlayableApp {
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: game.appPath)])
                }
            }
            Divider()
            Button("从游戏库移除", role: .destructive) { model.deleteGame(game) }
        }
    }
}

private struct AddLibraryTile: View {
    @EnvironmentObject private var model: AppModel
    @State private var hovering = false

    var body: some View {
        Button {
            LumenPanels.importGame(into: model)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(hovering ? 0.045 : 0.018))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        .white.opacity(hovering ? 0.25 : 0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 6])
                    )
                VStack(spacing: 9) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                    Text("导入游戏")
                        .font(LumenFont.text(11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(hovering ? 0.75 : 0.34))
            }
            .frame(height: 184)
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.16)) { hovering = value }
        }
    }
}

private struct EmptySearchView: View {
    let query: String
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.36))
            Text("没有找到匹配的游戏")
                .font(LumenFont.display(20))
                .foregroundStyle(.white.opacity(0.82))
            Text("试试其他关键词，或清除搜索与筛选条件。")
                .font(LumenFont.text(12))
                .foregroundStyle(.white.opacity(0.4))
            Button("清除搜索") {
                model.searchText = ""
                model.libraryFilter = .all
            }
            .buttonStyle(.plain)
            .font(LumenFont.text(11.5, weight: .medium))
            .foregroundStyle(.black.opacity(0.8))
            .padding(.horizontal, 15)
            .frame(height: 32)
            .background(Capsule().fill(.white.opacity(0.88)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}
