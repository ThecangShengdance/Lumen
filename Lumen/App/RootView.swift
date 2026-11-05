import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var gamepad: GamepadManager
    @Environment(\.lumenPalette) private var palette

    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    @State private var idleTimer: Timer?
    @State private var lastActivity = Date()
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            AmbientBackground(palette: model.palette, settings: model.settings)
                .ignoresSafeArea()

            tabContent

            if !model.isBooting,
               model.detailGameID == nil,
               !model.isEditorPresented,
               !model.isSettingsPresented,
               !model.isIdleCarouselPresented {
                LumenTopBar()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
                    .zIndex(5)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, palette.accent.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .zIndex(6)
            }

            if model.detailGameID != nil {
                GameDetailView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }

            if model.isEditorPresented, let editorGame = model.editorGame {
                GameEditorView(game: editorGame, isNew: model.editorIsNew)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
            }

            if model.isSettingsPresented {
                SettingsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(40)
            }

            if let toast = model.toast {
                ToastView(toast: toast)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 92)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
            }

            if model.isIdleCarouselPresented {
                IdleCarouselView()
                    .transition(.opacity)
                    .zIndex(60)
            }

            if model.isBooting {
                BootView()
                    .transition(.opacity)
                    .zIndex(100)
            }

            if dropTargeted {
                dropOverlay
                    .transition(.opacity)
                    .zIndex(90)
            }
        }
        .environment(\.lumenPalette, model.palette)
        .frame(minWidth: 1180, minHeight: 760)
        .background(WindowConfigurator(launchFullScreen: model.settings.launchFullScreen, isBooting: model.isBooting))
        .preferredColorScheme(.dark)
        .animation(.lumen, value: model.detailGameID)
        .animation(.lumen, value: model.isEditorPresented)
        .animation(.lumen, value: model.isSettingsPresented)
        .animation(.lumen, value: model.isBooting)
        .animation(.lumen, value: model.toast?.id)
        .onAppear(perform: setUp)
        .onDisappear(perform: tearDown)
        .onChange(of: model.settings.idleCarouselDelay) { _ in
            noteActivity()
        }
        .onChange(of: model.isBooting) { booting in
            if !booting { noteActivity() }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
    }

    // MARK: - Content

    private var tabContent: some View {
        ZStack {
            if model.tab == .home {
                HomeView()
                    .transition(.opacity)
            } else {
                LibraryView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: model.tab)
    }

    private var dropOverlay: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.accent.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            palette.accent.opacity(0.85),
                            style: StrokeStyle(lineWidth: 1.4, dash: [7, 7])
                        )
                }
                .padding(26)

            VStack(spacing: 18) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(palette.accent)
                Text("松开以导入游戏")
                    .font(LumenFont.display(24, weight: .semibold))
                    .foregroundStyle(.white)
                Text("拖入任意 macOS 游戏 App（.app），Lumen 会读取名称、图标与版本信息。")
                    .font(LumenFont.text(13))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard model.detailGameID == nil, !model.isEditorPresented, !model.isSettingsPresented else {
            model.showToast("请先关闭当前窗口", icon: "exclamationmark.triangle.fill")
            return false
        }
        guard let provider = providers.first else { return false }

        loadFileURL(from: provider) { url in
            DispatchQueue.main.async {
                guard let url else { return }
                guard LumenPanels.validateApp(url) else {
                    model.alert = LumenAlert(
                        title: "无法导入这个 App",
                        message: "它不是一个完整的 macOS 应用包（缺少 Info.plist 或可执行文件）。请拖入 Applications 文件夹中的游戏 App。"
                    )
                    return
                }
                model.openEditor(importing: url)
            }
        }
        return true
    }

    // MARK: - Lifecycle

    private func setUp() {
        NSApp.activate(ignoringOtherApps: true)

        model.controllerConnected = gamepad.isConnected
        model.controllerName = gamepad.controllerName
        model.controllerBattery = gamepad.batteryLevel

        gamepad.onAction = { [weak model] action in
            Task { @MainActor in
                guard let model else { return }
                noteActivity()
                if model.isIdleCarouselPresented {
                    model.endIdleCarousel()
                    return
                }
                model.handle(action)
            }
        }
        gamepad.onConnectionChange = { connected, name, battery in
            Task { @MainActor in
                let wasConnected = model.controllerConnected
                model.controllerConnected = connected
                model.controllerName = name
                model.controllerBattery = battery
                if connected, !wasConnected {
                    model.showToast("已连接 \(name)", icon: "gamecontroller.fill")
                }
            }
        }

        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                var consumed = false
                MainActor.assumeIsolated {
                    consumed = handleKey(event)
                }
                return consumed ? nil : event
            }
        }

        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
            ) { event in
                MainActor.assumeIsolated { noteActivity() }
                return event
            }
        }

        startIdleTimer()
    }

    private func tearDown() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil
        gamepad.onAction = nil
        gamepad.onConnectionChange = nil
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        if model.isIdleCarouselPresented {
            noteActivity()
            return true
        }
        noteActivity()

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.keyCode
        let characters = event.charactersIgnoringModifiers?.lowercased()

        if model.isBooting {
            model.finishBoot()
            return true
        }

        if flags.contains(.command) {
            guard !model.isEditorPresented, !model.isSettingsPresented else { return false }
            switch characters {
            case "f":
                model.closeDetail()
                model.selectTab(.library)
                DispatchQueue.main.async { model.focusSearchToken += 1 }
                return true
            case "o":
                LumenPanels.importGame(into: model)
                return true
            case ",":
                model.presentSettings()
                return true
            case "1":
                model.closeDetail()
                model.selectTab(.home)
                return true
            case "2":
                model.closeDetail()
                model.selectTab(.library)
                return true
            default:
                return false
            }
        }

        if model.isEditorPresented {
            if key == 53 {
                model.closeEditor()
                return true
            }
            return false
        }

        if model.isSettingsPresented {
            if key == 53 {
                model.closeSettings()
                return true
            }
            return false
        }

        if NSApp.keyWindow?.firstResponder is NSTextView {
            if key == 53 {
                NSApp.keyWindow?.makeFirstResponder(nil)
                model.searchText = ""
                return true
            }
            return false
        }

        if model.isTrailerPresented {
            if key == 53 {
                withAnimation(.lumen) { model.isTrailerPresented = false }
                return true
            }
            return false
        }

        switch key {
        case 123:
            model.handle(.left)
            return true
        case 124:
            model.handle(.right)
            return true
        case 125:
            model.handle(.down)
            return true
        case 126:
            model.handle(.up)
            return true
        case 36, 76, 49:
            model.handle(.confirm)
            return true
        case 53:
            model.handle(.cancel)
            return true
        case 48:
            model.handle(flags.contains(.shift) ? .previousTab : .nextTab)
            return true
        default:
            break
        }

        guard !event.isARepeat else { return false }
        switch characters {
        case "f", "y":
            model.handle(.favorite)
            return true
        case "x":
            model.handle(.options)
            return true
        case "m":
            model.handle(.menu)
            return true
        case "e":
            if model.detailGameID != nil {
                model.presentEditor(for: model.detailGame)
            } else if model.tab == .library {
                model.presentEditor()
            } else {
                model.presentEditor()
            }
            return true
        default:
            return false
        }
    }

    // MARK: - Idle timer

    private func startIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in checkIdle() }
        }
    }

    private func noteActivity() {
        lastActivity = Date()
        if model.isIdleCarouselPresented {
            model.endIdleCarousel()
        }
    }

    private func checkIdle() {
        let delay = model.settings.idleCarouselDelay
        guard delay != .off else { return }
        guard NSApp.isActive, !model.isBooting else { return }
        guard !model.isEditorPresented,
              !model.isSettingsPresented,
              !model.isTrailerPresented,
              model.detailGameID == nil,
              model.tab == .home,
              !model.isIdleCarouselPresented else { return }
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["LUMEN_IDLE_SECONDS"].flatMap(Double.init),
           override > 0 {
            guard Date().timeIntervalSince(lastActivity) >= override else { return }
            model.beginIdleCarousel()
            return
        }
        #endif
        guard Date().timeIntervalSince(lastActivity) >= delay.seconds else { return }
        model.beginIdleCarousel()
    }
}
