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
        model.openEditor(importing: url)
    }

    static func validateApp(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "app"
            && FileManager.default.fileExists(atPath: url.path)
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
