import AppKit
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case library

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "主页"
        case .library: "游戏库"
        }
    }
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .library: "square.grid.2x2.fill"
        }
    }
}

enum HomeFocus: Equatable {
    case shelf
    case actions
}

enum GamepadAction {
    case up, down, left, right
    case confirm, cancel
    case menu, options
    case nextTab, previousTab
    case favorite
}

struct LumenToast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var icon: String = "checkmark.circle.fill"
}

struct LumenAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

private struct PersistedLibrary: Codable {
    var games: [Game]
    var settings: AppSettings
    var selectedGameID: UUID? = nil
}

@MainActor
final class AppModel: ObservableObject {
    @Published var games: [Game] = [] {
        didSet { if isLoaded { persist() } }
    }
    @Published var settings = AppSettings() {
        didSet { if isLoaded { persist() } }
    }

    @Published var selectedGameID: UUID? {
        didSet { if isLoaded { persist() } }
    }
    @Published var tab: AppTab = .home
    @Published var homeFocus: HomeFocus = .shelf
    @Published var actionIndex: Int = 0
    @Published var detailGameID: UUID?
    @Published var isEditorPresented = false
    @Published var editorGame: Game?
    @Published var editorIsNew = false
    @Published var isSettingsPresented = false
    @Published var searchText: String = ""
    @Published var focusSearchToken = 0
    @Published var libraryFilter: LibraryFilter = .all
    @Published var libraryColumns: Int = 4
    @Published var isBooting = true
    @Published var toast: LumenToast?
    @Published var alert: LumenAlert?
    @Published var controllerConnected = false
    @Published var controllerName = ""
    @Published var controllerBattery: Float?
    @Published var isTrailerPresented = false
    @Published var isIdleCarouselPresented = false

    private var isLoaded = false
    private var toastTask: Task<Void, Never>?

    init() {
        LumenPaths.ensureDirectories()
        load()
        #if DEBUG
        applyDebugLaunchArguments()
        #endif
    }

    #if DEBUG
    /// Hidden routes used by the local screenshot harness and UI checks.
    private func applyDebugLaunchArguments() {
        let arguments = CommandLine.arguments
        if arguments.contains("--no-boot") || arguments.contains("--library")
            || arguments.contains("--detail") || arguments.contains("--settings")
            || arguments.contains("--editor") || arguments.contains("--new-editor")
            || arguments.contains("--trailer") || arguments.contains("--render") {
            isBooting = false
        }
        if let flag = arguments.firstIndex(of: "--theme"),
           arguments.indices.contains(flag + 1),
           let theme = ThemeStyle(rawValue: arguments[flag + 1]) {
            settings.theme = theme
        }
        if let flag = arguments.firstIndex(of: "--accent"),
           arguments.indices.contains(flag + 1) {
            settings.customAccentHex = arguments[flag + 1]
        }
        if arguments.contains("--library") {
            tab = .library
        }
        if arguments.contains("--detail"), detailGameID == nil {
            detailGameID = selectedGameID
        }
        if arguments.contains("--trailer") {
            detailGameID = detailGameID ?? selectedGameID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self, self.detailGame?.trailerPath != nil else { return }
                self.isTrailerPresented = true
            }
        }
        if arguments.contains("--settings") {
            isSettingsPresented = true
        }
        if arguments.contains("--editor"), !isEditorPresented {
            presentEditor()
        }
        if arguments.contains("--new-editor"), !isEditorPresented {
            presentNewGame()
        }
        if let flag = arguments.firstIndex(of: "--import-app"),
           arguments.indices.contains(flag + 1) {
            let appURL = URL(fileURLWithPath: arguments[flag + 1])
            let shouldSave = arguments.contains("--import-save")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self else { return }
                self.openEditor(importing: appURL)
                if shouldSave, var draft = self.editorGame {
                    draft.overview = "通过 Lumen 导入的本地游戏。它会出现在游戏库中，并可直接从这里启动。"
                    draft.genre = "动作冒险"
                    draft.publisher = "独立发行"
                    _ = self.saveGame(draft, iconImage: nil, heroURL: nil, posterURL: nil, trailerURL: nil)
                    self.tab = .library
                }
            }
        }
        if arguments.contains("--launch-imported") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self,
                      let game = self.games.first(where: { !$0.isShowcase && $0.hasPlayableApp }) else { return }
                self.launch(game)
            }
        }
    }
    #endif

    // MARK: - Persistence

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: LumenPaths.libraryFile),
           let state = try? decoder.decode(PersistedLibrary.self, from: data) {
            games = state.games
            settings = state.settings
        } else if FileManager.default.fileExists(atPath: LumenPaths.libraryFile.path) {
            let backup = LumenPaths.libraryFile.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: LumenPaths.libraryFile, to: backup)
            alert = LumenAlert(title: "游戏库读取失败", message: "已保留备份并创建新的游戏库。备份位于 \(backup.lastPathComponent)。")
        }

        if games.isEmpty {
            games = MediaStore.shared.seededShowcaseGames()
            settings.didSeedShowcase = true
        }
        if let savedID = (try? Data(contentsOf: LumenPaths.libraryFile))
            .flatMap({ try? decoder.decode(PersistedLibrary.self, from: $0) })?
            .selectedGameID,
           games.contains(where: { $0.id == savedID }) {
            selectedGameID = savedID
        }
        if selectedGameID == nil || !games.contains(where: { $0.id == selectedGameID }) {
            selectedGameID = sortedGames.first?.id
        }
        isLoaded = true
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let state = PersistedLibrary(games: games, settings: settings, selectedGameID: selectedGameID)
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: LumenPaths.libraryFile, options: .atomic)
    }

    // MARK: - Derived state

    var sortedGames: [Game] {
        games.sorted {
            if $0.sortOrder == $1.sortOrder { return $0.addedAt < $1.addedAt }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var selectedGame: Game? {
        guard let selectedGameID else { return sortedGames.first }
        return games.first(where: { $0.id == selectedGameID }) ?? sortedGames.first
    }

    var detailGame: Game? {
        guard let detailGameID else { return nil }
        return games.first(where: { $0.id == detailGameID })
    }

    var libraryGames: [Game] {
        var result = sortedGames
        switch libraryFilter {
        case .all:
            break
        case .favorites:
            result = result.filter(\.isFavorite)
        case .recent:
            result = result.filter { $0.lastPlayedAt != nil }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.developer.localizedCaseInsensitiveContains(query)
                    || $0.genre.localizedCaseInsensitiveContains(query)
            }
        }
        return result
    }

    var favoriteCount: Int { games.filter(\.isFavorite).count }
    var installedCount: Int { games.filter { $0.hasPlayableApp }.count }

    var palette: LumenPalette { settings.palette }

    var hasOverlay: Bool {
        detailGameID != nil || isEditorPresented || isSettingsPresented
    }

    func game(with id: UUID) -> Game? {
        games.first(where: { $0.id == id })
    }

    func isSelected(_ game: Game) -> Bool {
        selectedGame?.id == game.id
    }

    // MARK: - Selection & navigation

    func select(_ id: UUID, focusShelf: Bool = true) {
        guard selectedGameID != id else { return }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            selectedGameID = id
            if focusShelf { homeFocus = .shelf }
        }
        haptic(.alignment)
    }

    func selectNext() {
        let list = sortedGames
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: { $0.id == selectedGameID }) ?? 0
        let next = list[(current + 1) % list.count]
        select(next.id)
    }

    func selectPrevious() {
        let list = sortedGames
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: { $0.id == selectedGameID }) ?? 0
        let previous = list[(current - 1 + list.count) % list.count]
        select(previous.id)
    }

    func cycleTab(by offset: Int) {
        let tabs = AppTab.allCases
        guard let index = tabs.firstIndex(of: tab) else { return }
        let next = tabs[(index + offset + tabs.count) % tabs.count]
        withAnimation(.easeInOut(duration: 0.32)) { tab = next }
        if next == .library, !libraryGames.contains(where: { $0.id == selectedGameID }) {
            selectedGameID = libraryGames.first?.id
        }
        haptic(.alignment)
    }

    func selectTab(_ newTab: AppTab) {
        guard tab != newTab else { return }
        withAnimation(.easeInOut(duration: 0.32)) { tab = newTab }
        if newTab == .library, !libraryGames.contains(where: { $0.id == selectedGameID }) {
            selectedGameID = libraryGames.first?.id
        }
    }

    func moveLibrarySelection(_ dx: Int, _ dy: Int) {
        let list = libraryGames
        guard !list.isEmpty else { return }
        guard let current = list.firstIndex(where: { $0.id == selectedGameID }) else {
            selectedGameID = list.first?.id
            return
        }
        var target = current + dx + dy * max(1, libraryColumns)
        if target < 0 { target = 0 }
        if target >= list.count { target = list.count - 1 }
        if target != current {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                selectedGameID = list[target].id
            }
            haptic(.alignment)
        }
    }

    // MARK: - Idle carousel

    func beginIdleCarousel() {
        guard !isBooting,
              !isIdleCarouselPresented,
              !isEditorPresented,
              !isSettingsPresented,
              !isTrailerPresented,
              detailGameID == nil,
              tab == .home,
              !sortedGames.isEmpty,
              settings.idleCarouselDelay != .off else { return }

        if !sortedGames.contains(where: { $0.id == selectedGameID }) {
            selectedGameID = sortedGames.first?.id
        }
        withAnimation(.easeInOut(duration: 0.6)) {
            isIdleCarouselPresented = true
        }
    }

    func endIdleCarousel() {
        guard isIdleCarouselPresented else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            isIdleCarouselPresented = false
        }
    }

    // MARK: - Overlays

    func openDetail(for game: Game? = nil) {
        guard let target = game ?? selectedGame else { return }
        isTrailerPresented = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            detailGameID = target.id
        }
    }

    func closeDetail() {
        isTrailerPresented = false
        withAnimation(.easeInOut(duration: 0.28)) { detailGameID = nil }
    }

    func presentEditor(for game: Game? = nil) {
        let editing = game ?? selectedGame
        if let editing {
            editorGame = editing
            editorIsNew = false
        } else {
            editorGame = Game(sortOrder: nextSortOrder)
            editorIsNew = true
        }
        isTrailerPresented = false
        detailGameID = nil
        withAnimation(.spring(response: 0.48, dampingFraction: 0.9)) {
            isEditorPresented = true
        }
        haptic(.alignment)
    }

    func presentNewGame() {
        editorGame = Game(sortOrder: nextSortOrder)
        editorIsNew = true
        isTrailerPresented = false
        detailGameID = nil
        isEditorPresented = true
        haptic(.alignment)
    }

    func openEditor(importing appURL: URL) {
        let info = MediaStore.shared.inspectApp(at: appURL)
        var draft = Game(
            title: info.title,
            tagline: "IMPORTED GAME",
            developer: info.developer,
            genre: "游戏",
            version: info.version,
            appPath: appURL.path,
            sortOrder: nextSortOrder
        )
        draft.publisher = ""
        editorGame = draft
        editorIsNew = true
        isTrailerPresented = false
        detailGameID = nil
        isEditorPresented = true
        haptic(.alignment)
    }

    func closeEditor() {
        isEditorPresented = false
        editorGame = nil
        editorIsNew = false
    }

    func presentSettings() {
        withAnimation(.easeInOut(duration: 0.32)) { isSettingsPresented = true }
    }

    func closeSettings() {
        withAnimation(.easeInOut(duration: 0.25)) { isSettingsPresented = false }
    }

    var nextSortOrder: Int {
        (games.map(\.sortOrder).max() ?? -1) + 1
    }

    // MARK: - Mutations

    func toggleFavorite(_ game: Game? = nil) {
        guard let target = game ?? selectedGame,
              let index = games.firstIndex(where: { $0.id == target.id }) else { return }
        games[index].isFavorite.toggle()
        haptic(.generic)
        showToast(games[index].isFavorite ? "已加入收藏" : "已取消收藏", icon: games[index].isFavorite ? "heart.fill" : "heart")
    }

    @discardableResult
    func saveGame(
        _ draft: Game,
        iconImage: NSImage?,
        heroURL: URL?,
        posterURL: URL?,
        trailerURL: URL?
    ) -> Bool {
        var updated = draft
        let wasNew = editorIsNew
        let old = games.first(where: { $0.id == draft.id })
        let store = MediaStore.shared

        do {
            if let iconImage {
                let newPath = try store.storeIcon(iconImage, for: updated.id)
                if let oldPath = old?.iconPath, oldPath != newPath { store.removeMedia(path: oldPath) }
                updated.iconPath = newPath
            } else if var iconPath = updated.iconPath, !FileManager.default.fileExists(atPath: iconPath) {
                iconPath = ""
                updated.iconPath = nil
            } else if updated.iconPath == nil, !updated.appPath.isEmpty {
                let info = store.inspectApp(at: URL(fileURLWithPath: updated.appPath))
                if let icon = info.icon {
                    updated.iconPath = try? store.storeIcon(icon, for: updated.id)
                }
            }

            if let heroURL {
                let newPath = try store.copyMedia(from: heroURL, for: updated.id, kind: .hero)
                if let oldPath = old?.heroPath, oldPath != newPath { store.removeMedia(path: oldPath) }
                updated.heroPath = newPath
            } else if let oldPath = old?.heroPath, updated.heroPath != oldPath {
                store.removeMedia(path: oldPath)
            }

            if let posterURL {
                let newPath = try store.copyMedia(from: posterURL, for: updated.id, kind: .poster)
                if let oldPath = old?.posterPath, oldPath != newPath { store.removeMedia(path: oldPath) }
                updated.posterPath = newPath
            } else if let oldPath = old?.posterPath, updated.posterPath != oldPath {
                store.removeMedia(path: oldPath)
            }

            if let trailerURL {
                let newPath = try store.copyMedia(from: trailerURL, for: updated.id, kind: .trailer)
                if let oldPath = old?.trailerPath, oldPath != newPath { store.removeMedia(path: oldPath) }
                updated.trailerPath = newPath
            } else if let oldPath = old?.trailerPath, updated.trailerPath != oldPath {
                store.removeMedia(path: oldPath)
            }

            updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if updated.title.isEmpty { updated.title = "Untitled Game" }

            if updated.hasPlayableApp { updated.isShowcase = false }
            if let index = games.firstIndex(where: { $0.id == updated.id }) {
                games[index] = updated
            } else {
                games.append(updated)
            }
            selectedGameID = updated.id
            closeEditor()
            showToast(wasNew ? "游戏已添加" : "已保存更改", icon: "sparkles")
            haptic(.levelChange)
            return true
        } catch {
            alert = LumenAlert(title: "无法保存媒体文件", message: error.localizedDescription)
            return false
        }
    }

    func deleteGame(_ game: Game) {
        let title = game.title
        withAnimation(.easeInOut(duration: 0.25)) {
            games.removeAll(where: { $0.id == game.id })
            MediaStore.shared.removeAllMedia(for: game.id)
            if selectedGameID == game.id { selectedGameID = sortedGames.first?.id }
            if detailGameID == game.id { detailGameID = nil }
            if editorGame?.id == game.id { closeEditor() }
        }
        showToast("已移除「\(title)」", icon: "trash.fill")
    }

    func restoreShowcase() {
        let fresh = MediaStore.shared.seededShowcaseGames()
        let existingTitles = Set(games.filter(\.isShowcase).map(\.title))
        let additions = fresh.filter { !existingTitles.contains($0.title) }
        guard !additions.isEmpty else {
            showToast("展示游戏已存在", icon: "sparkles")
            return
        }
        games.append(contentsOf: additions)
        selectedGameID = additions.first?.id
        showToast("已恢复 \(additions.count) 个展示游戏", icon: "sparkles")
    }

    func removeShowcaseGames() {
        let ids = games.filter(\.isShowcase).map(\.id)
        for id in ids { MediaStore.shared.removeAllMedia(for: id) }
        games.removeAll(where: \.isShowcase)
        if let selectedGameID, ids.contains(selectedGameID) { self.selectedGameID = sortedGames.first?.id }
        showToast("展示内容已清除", icon: "sparkles")
    }

    func resetAppearance() {
        settings.theme = .aurora
        settings.customAccentHex = nil
        settings.motionEnabled = true
        settings.grainEnabled = true
        settings.ambientIntensity = 0.92
        showToast("外观已恢复默认", icon: "paintbrush.fill")
    }

    func revealLibraryFolder() {
        LumenPaths.ensureDirectories()
        NSWorkspace.shared.open(LumenPaths.supportDirectory)
    }

    func reveal(_ game: Game) {
        guard let appURL = game.appURL, game.hasPlayableApp else { return }
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    // MARK: - Launching

    func launch(_ game: Game? = nil) {
        guard let target = game ?? selectedGame else {
            presentNewGame()
            return
        }
        guard target.hasPlayableApp, let appURL = target.appURL else {
            showToast("先为「\(target.title)」指定游戏 App", icon: "link.badge.plus")
            presentEditor(for: target)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = true
        showToast("正在启动 \(target.title)", icon: "play.fill")

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.alert = LumenAlert(title: "启动失败", message: "无法启动「\(target.title)」。\n\n\(error.localizedDescription)")
                } else {
                    if let index = self.games.firstIndex(where: { $0.id == target.id }) {
                        self.games[index].lastPlayedAt = Date()
                        self.games[index].launchCount += 1
                    }
                    self.haptic(.levelChange)
                }
            }
        }
    }

    // MARK: - Controller routing

    func handle(_ action: GamepadAction) {
        if isEditorPresented {
            if action == .cancel { closeEditor() }
            return
        }
        if isSettingsPresented {
            if action == .cancel { closeSettings() }
            return
        }
        if detailGameID != nil {
            handleDetail(action)
            return
        }

        switch action {
        case .nextTab:
            cycleTab(by: 1)
        case .previousTab:
            cycleTab(by: -1)
        case .menu:
            presentSettings()
        case .cancel:
            if tab == .library { selectTab(.home) }
        default:
            if tab == .home {
                handleHome(action)
            } else {
                handleLibrary(action)
            }
        }
    }

    private func handleHome(_ action: GamepadAction) {
        switch action {
        case .left:
            if homeFocus == .shelf { selectPrevious() }
            else { actionIndex = max(0, actionIndex - 1); haptic(.alignment) }
        case .right:
            if homeFocus == .shelf { selectNext() }
            else { actionIndex = min(2, actionIndex + 1); haptic(.alignment) }
        case .up:
            if homeFocus == .shelf { homeFocus = .actions; actionIndex = 0; haptic(.alignment) }
            else if actionIndex > 0 { actionIndex -= 1; haptic(.alignment) }
        case .down:
            if homeFocus == .actions {
                if actionIndex < 2 { actionIndex += 1; haptic(.alignment) }
                else { homeFocus = .shelf; actionIndex = 0; haptic(.alignment) }
            }
        case .confirm:
            if homeFocus == .shelf {
                launch(selectedGame)
            } else {
                switch actionIndex {
                case 0: launch(selectedGame)
                case 1: openDetail()
                default: presentEditor()
                }
            }
        case .options:
            presentEditor()
        case .favorite:
            toggleFavorite()
        default:
            break
        }
    }

    private func handleLibrary(_ action: GamepadAction) {
        switch action {
        case .left: moveLibrarySelection(-1, 0)
        case .right: moveLibrarySelection(1, 0)
        case .up: moveLibrarySelection(0, -1)
        case .down: moveLibrarySelection(0, 1)
        case .confirm: openDetail()
        case .options: presentEditor()
        case .favorite: toggleFavorite()
        default: break
        }
    }

    private func handleDetail(_ action: GamepadAction) {
        if isTrailerPresented {
            if action == .cancel { isTrailerPresented = false }
            return
        }
        switch action {
        case .cancel:
            closeDetail()
        case .confirm:
            launch(detailGame)
        case .options:
            if let detailGame { presentEditor(for: detailGame) }
        case .favorite:
            toggleFavorite(detailGame)
        case .menu:
            if detailGame?.trailerPath != nil {
                withAnimation(.lumen) { isTrailerPresented = true }
            }
        case .left:
            selectPrevious()
            if let selectedGameID { detailGameID = selectedGameID }
        case .right:
            selectNext()
            if let selectedGameID { detailGameID = selectedGameID }
        default:
            break
        }
    }

    // MARK: - Feedback

    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard settings.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    func showToast(_ text: String, icon: String = "checkmark.circle.fill") {
        let item = LumenToast(text: text, icon: icon)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { toast = item }
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                if self?.toast?.id == item.id { self?.toast = nil }
            }
        }
    }

    func finishBoot() {
        withAnimation(.easeInOut(duration: 0.6)) { isBooting = false }
    }
}
