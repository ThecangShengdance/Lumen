import SwiftUI

@main
struct LumenApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var gamepad = GamepadManager()

    init() {
        #if DEBUG
        OffscreenRender.runIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(gamepad)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1480, height: 920)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入游戏…") {
                    LumenPanels.importGame(into: model)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("游戏") {
                Button("主页") {
                    model.closeDetail()
                    model.selectTab(.home)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("游戏库") {
                    model.closeDetail()
                    model.selectTab(.library)
                }
                .keyboardShortcut("2", modifiers: .command)

                Divider()

                Button("设置…") {
                    model.presentSettings()
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("刷新手柄连接") {
                    gamepad.rescan()
                    model.showToast("正在查找手柄", icon: "gamecontroller")
                }
            }
        }
    }
}
