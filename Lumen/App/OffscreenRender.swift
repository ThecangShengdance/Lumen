#if DEBUG
import AppKit
import SwiftUI

/// Renders the launcher UI without relying on an on-screen window.
/// Used by the local screenshot harness when the Mac is locked or headless.
@MainActor
enum OffscreenRender {
    static func runIfRequested() {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--render"),
              arguments.indices.contains(flag + 1) else { return }
        render(to: arguments[flag + 1])
        exit(0)
    }

    private static func render(to path: String) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let model = AppModel()
        let gamepad = GamepadManager()
        let arguments = CommandLine.arguments
        var size = NSSize(width: 1480, height: 920)
        if let sizeFlag = arguments.firstIndex(of: "--render-size"),
           arguments.indices.contains(sizeFlag + 1) {
            let parts = arguments[sizeFlag + 1].split(separator: "x").compactMap { Double($0) }
            if parts.count == 2, parts[0] >= 900, parts[1] >= 600 {
                size = NSSize(width: parts[0], height: parts[1])
            }
        }

        let root = RootView()
            .environmentObject(model)
            .environmentObject(gamepad)
            .environment(\.lumenPalette, model.palette)
            .frame(width: size.width, height: size.height)
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.contentsScale = 2

        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -4000, y: -4000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.backgroundColor = .black
        window.orderFrontRegardless()

        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(2.0))
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        window.orderOut(nil)
    }
}
#endif
