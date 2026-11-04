import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GameEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.lumenPalette) private var palette

    let isNew: Bool
    @State private var draft: Game
    @State private var pendingHeroURL: URL?
    @State private var pendingPosterURL: URL?
    @State private var pendingTrailerURL: URL?
    @State private var pendingIcon: NSImage?
    @State private var iconIsCustom = false
    @State private var customAccent: Color
    @State private var heroDropTargeted = false
    @State private var trailerDropTargeted = false
    @State private var confirmsDelete = false

    init(game: Game, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: game)
        _customAccent = State(initialValue: Color(hexString: game.accentHex ?? "") ?? Color(hex: 0x70E7FF))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1.0, (proxy.size.width - 48) / 1140, (proxy.size.height - 20) / 830)
            ZStack {
                background(size: proxy.size)

                VStack(spacing: 0) {
                    topBar
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 1)

                    HStack(alignment: .top, spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            mediaColumn
                                .padding(24)
                        }
                        .frame(width: 424)

                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 1)

                        ScrollView(showsIndicators: false) {
                            formColumn
                                .padding(26)
                                .padding(.trailing, 6)
                        }
                    }
                }
                .frame(width: 1140, height: 830)
                .background {
                    ZStack {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        Color.black.opacity(0.3)
                        LinearGradient(
                            colors: [.white.opacity(0.045), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.6), radius: 60, y: 26)
                .scaleEffect(scale)
                .padding(.top, 10)
            }
        }
        .tint(palette.accent)
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .confirmationDialog(
            "从游戏库移除「\(draft.title)」？",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) {
                model.deleteGame(draft)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("不会删除游戏 App 本身，只会移除这条收藏与导入的素材。")
        }
    }

    // MARK: - Background

    private func background(size: CGSize) -> some View {
        ZStack {
            AmbientBackground(palette: palette, settings: model.settings)
            GameArtwork(game: previewGame)
                .frame(width: size.width * 1.15, height: size.height * 1.15)
                .blur(radius: 55)
                .opacity(0.22)
                .clipped()
            Color.black.opacity(0.35)
            LinearGradient(
                colors: [.black.opacity(0.2), .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            IconCircleButton(symbol: "xmark", size: 36, help: "取消") {
                model.closeEditor()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isNew ? "添加游戏" : "编辑游戏")
                    .font(LumenFont.display(19, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Text(isNew ? "把你自己的游戏带进 Lumen" : "修改条目信息与视觉素材")
                    .font(LumenFont.label(9.5))
                    .foregroundStyle(.white.opacity(0.36))
            }

            Spacer()

            if !isNew {
                IconCircleButton(symbol: "trash", size: 36, help: "从游戏库移除") {
                    confirmsDelete = true
                }
            }

            LumenActionButton(
                title: isNew ? "添加到游戏库" : "保存更改",
                symbol: "checkmark",
                style: .primary
            ) {
                save()
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.38)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 22)
        .frame(height: 68)
    }

    // MARK: - Media column

    private var mediaColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionEyebrow(text: "Visual Assets", accent: palette.accent)
                Spacer()
                Text("仅存放于本机")
                    .font(LumenFont.label(8.5))
                    .foregroundStyle(.white.opacity(0.26))
            }

            VStack(alignment: .leading, spacing: 7) {
                Button(action: chooseHero) {
                    ZStack(alignment: .bottomLeading) {
                        GameArtwork(game: previewGame)
                            .frame(maxWidth: .infinity)
                            .frame(height: 226)
                            .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.14), .black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("主视觉")
                                    .font(LumenFont.label(9))
                                    .tracking(1.4)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("16:9 · 建议 2560 × 1440")
                                    .font(LumenFont.label(8.5))
                                    .foregroundStyle(.white.opacity(0.34))
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                Image(systemName: "photo.badge.plus")
                                Text(hasHero ? "更换" : "选择图片")
                            }
                            .font(LumenFont.label(9))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Capsule().fill(.black.opacity(0.32)))
                        }
                        .padding(12)
                    }
                    .frame(height: 226)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(
                                heroDropTargeted ? palette.accent.opacity(0.9) : .white.opacity(0.12),
                                lineWidth: heroDropTargeted ? 2 : 1
                            )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                .onDrop(of: [.fileURL], isTargeted: $heroDropTargeted) { providers in
                    handleImageDrop(providers) { pendingHeroURL = $0 }
                }

                HStack {
                    Text(heroName)
                        .font(LumenFont.label(8.5))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(1)
                    Spacer()
                    if hasHero {
                        Button("移除") {
                            pendingHeroURL = nil
                            draft.heroPath = nil
                        }
                        .buttonStyle(.plain)
                        .font(LumenFont.label(8.5))
                        .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Button(action: choosePoster) {
                        ZStack(alignment: .bottomLeading) {
                            PosterArtwork(game: previewGame)
                                .frame(width: 148, height: 222)
                                .clipped()
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.68)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            HStack(spacing: 4) {
                                Image(systemName: "photo.badge.plus")
                                Text(hasPoster ? "更换海报" : "选择海报")
                            }
                            .font(LumenFont.label(8.5))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(10)
                        }
                        .frame(width: 148, height: 222)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Text("竖版海报 · 2:3")
                            .font(LumenFont.label(8))
                            .foregroundStyle(.white.opacity(0.28))
                        Spacer()
                        if hasPoster {
                            Button("移除") {
                                pendingPosterURL = nil
                                draft.posterPath = nil
                            }
                            .buttonStyle(.plain)
                            .font(LumenFont.label(8))
                            .foregroundStyle(.white.opacity(0.32))
                        }
                    }
                    .frame(width: 148)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Button(action: chooseIcon) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.04))
                            if let icon = iconPreview {
                                Image(nsImage: icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 92, height: 92)
                            } else {
                                GameIcon(game: previewGame, size: 92)
                            }
                            VStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.pencil")
                                    Text("更换")
                                }
                                .font(LumenFont.label(8))
                                .foregroundStyle(.white.opacity(0.66))
                                .padding(.bottom, 9)
                            }
                        }
                        .frame(width: 112, height: 112)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("图标 · 1:1")
                        .font(LumenFont.label(8))
                        .foregroundStyle(.white.opacity(0.28))

                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Button(action: chooseTrailer) {
                    HStack(spacing: 11) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(palette.accent.opacity(hasTrailer ? 0.18 : 0.08))
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.accent.opacity(hasTrailer ? 0.95 : 0.5))
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(hasTrailer ? "宣传片已就绪" : "添加宣传片")
                                .font(LumenFont.text(10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                            Text(trailerName)
                                .font(LumenFont.label(8))
                                .foregroundStyle(.white.opacity(0.3))
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(hasTrailer ? "更换" : "选择视频")
                            .font(LumenFont.label(8.5))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.white.opacity(trailerDropTargeted ? 0.09 : 0.04))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(
                                trailerDropTargeted ? palette.accent.opacity(0.8) : .white.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1, dash: hasTrailer ? [] : [5, 5])
                            )
                    }
                }
                .buttonStyle(.plain)
                .onDrop(of: [.fileURL], isTargeted: $trailerDropTargeted) { providers in
                    handleVideoDrop(providers)
                }

                if hasTrailer {
                    HStack {
                        Spacer()
                        Button("移除宣传片") {
                            pendingTrailerURL = nil
                            draft.trailerPath = nil
                        }
                        .buttonStyle(.plain)
                        .font(LumenFont.label(8))
                        .foregroundStyle(.white.opacity(0.32))
                    }
                    .padding(.horizontal, 2)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                Text("素材会复制到 Lumen 数据目录，原始文件不会被移动或修改。")
            }
            .font(LumenFont.label(8.5))
            .foregroundStyle(.white.opacity(0.26))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Form

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            editorSection("基本信息", note: "在主页与详情页中展示") {
                VStack(spacing: 14) {
                    EditorInput(label: "标题", placeholder: "例如：Eclipse Protocol", text: $draft.title)
                    EditorInput(label: "副标题 / 标语", placeholder: "一句话概括这段旅程", text: $draft.tagline)
                    EditorInput(
                        label: "介绍",
                        placeholder: "写下这款游戏的世界、玩法或你想记住的瞬间…",
                        text: $draft.overview,
                        axis: .vertical
                    )

                    HStack(spacing: 12) {
                        EditorInput(label: "开发商", placeholder: "Studio", text: $draft.developer)
                        EditorInput(label: "发行商", placeholder: "Publisher", text: $draft.publisher)
                    }

                    HStack(spacing: 12) {
                        EditorInput(label: "类型", placeholder: "动作冒险", text: $draft.genre)
                        EditorInput(label: "年份", placeholder: "2026", text: $draft.releaseYear)
                        EditorInput(label: "版本", placeholder: "1.0", text: $draft.version)
                    }
                }
            }

            editorSection("启动设置", note: "Lumen 只会打开这个 App，不参与游戏运行") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.accent.opacity(0.1))
                            Image(systemName: appIsValid ? "app.badge.checkmark" : "app.badge")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(palette.accent.opacity(0.9))
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(appIsValid ? appName : "尚未绑定游戏 App")
                                .font(LumenFont.text(11.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(1)
                            Text(appPathHint)
                                .font(LumenFont.label(8))
                                .foregroundStyle(.white.opacity(0.32))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        if appIsValid {
                            IconCircleButton(symbol: "folder", size: 34, help: "在 Finder 中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: draft.appPath)])
                            }
                        }

                        LumenActionButton(
                            title: appIsValid ? "更换 App" : "选择 App",
                            symbol: "cursorarrow.click",
                            style: .secondary
                        ) {
                            chooseApp()
                        }
                    }
                    .padding(13)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.035))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                    }

                    if draft.isShowcase && appIsValid {
                        Label("绑定 App 后，这条展示内容会自动转为你的游戏条目。", systemImage: "sparkles")
                            .font(LumenFont.label(8.5))
                            .foregroundStyle(palette.accent.opacity(0.7))
                    }
                }
            }

            editorSection("视觉标识", note: "用于高亮、光效与操作按钮") {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 10) {
                        Button {
                            draft.accentHex = nil
                        } label: {
                            ZStack {
                                Circle().fill(palette.accentGradient)
                                Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1)
                                if draft.accentHex == nil {
                                    Circle().strokeBorder(.white, lineWidth: 2).padding(-4)
                                }
                            }
                            .frame(width: 25, height: 25)
                        }
                        .buttonStyle(.plain)
                        .help("跟随主题")

                        ForEach(AccentChoice.allCases) { choice in
                            Button {
                                draft.accentHex = choice.rawValue
                                customAccent = choice.color
                            } label: {
                                ZStack {
                                    Circle().fill(choice.color)
                                    if draft.accentHex == choice.rawValue {
                                        Circle().strokeBorder(.white, lineWidth: 2).padding(-4)
                                    }
                                }
                                .frame(width: 25, height: 25)
                            }
                            .buttonStyle(.plain)
                            .help(choice.rawValue)
                        }

                        ColorPicker("", selection: $customAccent, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 26, height: 26)
                            .help("自定义颜色")
                            .onChange(of: customAccent) { value in
                                if let hex = value.hexString { draft.accentHex = hex }
                            }

                        Spacer()

                        Text(draft.accentHex == nil ? "跟随主题" : (draft.accentHex ?? ""))
                            .font(LumenFont.mono(9))
                            .foregroundStyle(.white.opacity(0.34))
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Image(systemName: draft.isFavorite ? "heart.fill" : "heart")
                            Text(draft.isFavorite ? "已收藏" : "未收藏")
                        }
                        .font(LumenFont.label(9))
                        .foregroundStyle(draft.isFavorite ? palette.accent : .white.opacity(0.35))
                        .onTapGesture { draft.isFavorite.toggle() }

                        Circle().fill(.white.opacity(0.18)).frame(width: 3, height: 3)

                        Text(draft.isShowcase ? "Lumen 展示内容" : "本地游戏")
                            .font(LumenFont.label(9))
                            .foregroundStyle(.white.opacity(0.32))
                    }
                }
            }

            if !canSave {
                Text("填写标题后即可保存到游戏库。")
                    .font(LumenFont.label(9))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.bottom, 22)
    }

    private func editorSection<Content: View>(
        _ title: String,
        note: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(LumenFont.text(12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text(note)
                    .font(LumenFont.label(8.5))
                    .foregroundStyle(.white.opacity(0.26))
                Spacer()
            }
            content()
        }
    }

    // MARK: - Helpers

    private var previewGame: Game {
        var game = draft
        if let pendingHeroURL { game.heroPath = pendingHeroURL.path }
        if let pendingPosterURL { game.posterPath = pendingPosterURL.path }
        if let pendingTrailerURL { game.trailerPath = pendingTrailerURL.path }
        return game
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasHero: Bool { pendingHeroURL != nil || draft.heroPath != nil }
    private var hasPoster: Bool { pendingPosterURL != nil || draft.posterPath != nil }
    private var hasTrailer: Bool { pendingTrailerURL != nil || draft.trailerPath != nil }

    private var heroName: String {
        if let pendingHeroURL { return pendingHeroURL.lastPathComponent }
        if let path = draft.heroPath { return URL(fileURLWithPath: path).lastPathComponent }
        return "尚未选择主视觉"
    }

    private var trailerName: String {
        if let pendingTrailerURL { return pendingTrailerURL.lastPathComponent }
        if let path = draft.trailerPath { return URL(fileURLWithPath: path).lastPathComponent }
        return "支持 MP4 / MOV 等常见格式"
    }

    private var appIsValid: Bool {
        !draft.appPath.isEmpty
            && FileManager.default.fileExists(atPath: draft.appPath)
            && URL(fileURLWithPath: draft.appPath).pathExtension.lowercased() == "app"
    }

    private var appName: String {
        appIsValid ? URL(fileURLWithPath: draft.appPath).deletingPathExtension().lastPathComponent : "未绑定"
    }

    private var appPathHint: String {
        draft.appPath.isEmpty ? "选择后会记住路径，下次从这里直接启动" : draft.appPath
    }

    private var iconPreview: NSImage? {
        if let pendingIcon { return pendingIcon }
        return ArtworkCache.shared.image(at: draft.iconPath)
    }

    private func chooseHero() {
        if let url = LumenPanels.chooseImage() { pendingHeroURL = url }
    }

    private func choosePoster() {
        if let url = LumenPanels.chooseImage() { pendingPosterURL = url }
    }

    private func chooseTrailer() {
        if let url = LumenPanels.chooseTrailer() { pendingTrailerURL = url }
    }

    private func chooseIcon() {
        guard let url = LumenPanels.chooseImage(),
              let image = NSImage(contentsOf: url) else { return }
        pendingIcon = image
        iconIsCustom = true
    }

    private func chooseApp() {
        guard let url = LumenPanels.chooseApp(), LumenPanels.validateApp(url) else { return }
        let info = MediaStore.shared.inspectApp(at: url)
        draft.appPath = url.path
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.title = info.title
        }
        if draft.developer.isEmpty { draft.developer = info.developer }
        if draft.version.isEmpty { draft.version = info.version }
        if !iconIsCustom {
            pendingIcon = info.icon
            draft.iconPath = nil
        }
        if draft.genre == "动作冒险" || draft.genre.isEmpty { draft.genre = "游戏" }
    }

    private func handleImageDrop(_ providers: [NSItemProvider], assign: @escaping (URL) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        loadFileURL(from: provider) { url in
            guard let url,
                  let type = UTType(filenameExtension: url.pathExtension),
                  type.conforms(to: .image) else { return }
            assign(url)
        }
        return true
    }

    private func handleVideoDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        loadFileURL(from: provider) { url in
            guard let url,
                  let type = UTType(filenameExtension: url.pathExtension),
                  type.conforms(to: .movie) || type.conforms(to: .video) else { return }
            pendingTrailerURL = url
        }
        return true
    }

    private func save() {
        guard canSave else { return }
        var payload = draft
        payload.title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.tagline = payload.tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.overview = payload.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.developer = payload.developer.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.publisher = payload.publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.genre = payload.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.releaseYear = payload.releaseYear.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.version = payload.version.trimmingCharacters(in: .whitespacesAndNewlines)

        model.saveGame(
            payload,
            iconImage: pendingIcon,
            heroURL: pendingHeroURL,
            posterURL: pendingPosterURL,
            trailerURL: pendingTrailerURL
        )
    }
}

// MARK: - Input

private struct EditorInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(LumenFont.label(9))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.36))

            Group {
                if axis == .vertical {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(4...8)
                        .frame(minHeight: 84, alignment: .topLeading)
                } else {
                    TextField(placeholder, text: $text)
                        .lineLimit(1)
                }
            }
            .textFieldStyle(.plain)
            .font(LumenFont.text(11.5))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.045))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.09), lineWidth: 1)
            }
        }
    }
}
