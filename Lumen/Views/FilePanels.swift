import AppKit
import UniformTypeIdentifiers

@MainActor
enum LumenPanels {
    static func chooseApp() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择游戏 App"
        panel.message = "选择要加入 Lumen 的游戏应用。Lumen 只负责启动它，不会修改游戏内容。"
        panel.prompt = "导入"
        panel.allowedContentTypes = [UTType(filenameExtension: "app") ?? .application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseImage() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择图片"
        panel.prompt = "使用"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseTrailer() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择宣传片"
        panel.prompt = "使用"
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func importGame(into model: AppModel) {
        guard let url = chooseApp() else { return }
        guard validateApp(url) else {
            model.alert = LumenAlert(
                title: "无法导入这个 App",
                message: "它不是一个完整的 macOS 应用包（缺少 Info.plist 或可执行文件）。请选择 Applications 文件夹中的游戏 App。"
            )
            return
        }
        model.openEditor(importing: url)
    }

    /// A launcher needs more than an `.app` folder name: the bundle must have
    /// readable metadata and an executable that `NSWorkspace` can open.
    static func validateApp(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "app" else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return false }

        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: infoURL.path) else { return false }
        guard let bundle = Bundle(url: url),
              bundle.bundleIdentifier != nil,
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { return false }
        return true
    }
}

func loadFileURL(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
    let identifier = UTType.fileURL.identifier
    guard provider.hasItemConformingToTypeIdentifier(identifier) else {
        completion(nil)
        return
    }
    provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
        var url: URL?
        if let data = item as? Data {
            url = URL(dataRepresentation: data, relativeTo: nil)
        } else if let direct = item as? URL {
            url = direct
        } else if let string = item as? String {
            url = URL(string: string)
        }
        DispatchQueue.main.async { completion(url) }
    }
}
