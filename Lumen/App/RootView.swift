import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var gamepad: GamepadManager
    @Environment(\.lumenPalette) private var palette

    @State private var keyMonitor: Any?
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            AmbientBackground(palette: model.palette, settings: model.settings)
                .ignoresSafeArea()

            tabContent

            if !model.isBooting,
               model.detailGameID == nil,
               !model.isEditorPresented,
               !model.isSettingsPresented {
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
                guard url.pathExtension.lowercased() == "app",
                      FileManager.default.fileExists(atPath: url.path) else {
                    model.showToast("请拖入 macOS 游戏 App（.app）", icon: "exclamationmark.triangle.fill")
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
            Task { @MainActor in model?.handle(action) }
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
    }

    private func tearDown() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        gamepad.onAction = nil
        gamepad.onConnectionChange = nil
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
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
}
