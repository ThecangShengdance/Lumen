import AppKit
import UniformTypeIdentifiers

enum LumenPaths {
    static var supportDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["LUMEN_SUPPORT_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Lumen", isDirectory: true)
    }

    static var libraryFile: URL { supportDirectory.appendingPathComponent("library.json") }
    static var mediaDirectory: URL { supportDirectory.appendingPathComponent("Media", isDirectory: true) }

    static func ensureDirectories() {
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }
}

enum MediaKind: String, CaseIterable {
    case icon
    case hero
    case poster
    case trailer

    var title: String {
        switch self {
        case .icon: "图标"
        case .hero: "主视觉"
        case .poster: "竖版海报"
        case .trailer: "宣传片"
        }
    }

    var hint: String {
        switch self {
        case .icon: "1:1"
        case .hero: "16:9"
        case .poster: "2:3"
        case .trailer: "视频"
        }
    }
}

struct MediaStore {
    static let shared = MediaStore()

    private var fm: FileManager { .default }

    func mediaDirectory(for gameID: UUID) -> URL {
        LumenPaths.mediaDirectory.appendingPathComponent(gameID.uuidString, isDirectory: true)
    }

    func copyMedia(from source: URL, for gameID: UUID, kind: MediaKind) throws -> String {
        let folder = mediaDirectory(for: gameID)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        removeExisting(kind: kind, in: folder)
        let ext = source.pathExtension.isEmpty ? (kind == .trailer ? "mov" : "png") : source.pathExtension.lowercased()
        let destination = folder.appendingPathComponent("\(kind.rawValue)-\(UUID().uuidString.prefix(8)).\(ext)")
        try fm.copyItem(at: source, to: destination)
        return destination.path
    }

    func storeIcon(_ image: NSImage, for gameID: UUID) throws -> String {
        let folder = mediaDirectory(for: gameID)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        removeExisting(kind: .icon, in: folder)

        let side = 1024
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        let source = image.size
        if source.width > 0, source.height > 0 {
            let scale = max(CGFloat(side) / source.width, CGFloat(side) / source.height)
            let drawSize = NSSize(width: source.width * scale, height: source.height * scale)
            let origin = NSPoint(
                x: (CGFloat(side) - drawSize.width) / 2,
                y: (CGFloat(side) - drawSize.height) / 2
            )
            image.draw(
                in: NSRect(origin: origin, size: drawSize),
                from: NSRect(origin: .zero, size: source),
                operation: .sourceOver,
                fraction: 1
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let data = rep.representation(using: .png, properties: [:])!
        let destination = folder.appendingPathComponent("icon-\(UUID().uuidString.prefix(8)).png")
        try data.write(to: destination, options: .atomic)
        return destination.path
    }

    private func removeExisting(kind: MediaKind, in folder: URL) {
        guard let contents = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in contents where file.lastPathComponent.hasPrefix(kind.rawValue + "-") {
            try? fm.removeItem(at: file)
        }
    }

    func removeAllMedia(for gameID: UUID) {
        try? fm.removeItem(at: mediaDirectory(for: gameID))
    }

    func removeMedia(path: String?) {
        guard let path, FileManager.default.fileExists(atPath: path) else { return }
        try? fm.removeItem(atPath: path)
    }

    func inspectApp(at url: URL) -> ImportedAppInfo {
        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary
        let name = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let developer = (info?["NSHumanReadableCopyright"] as? String)
            ?? (info?["CFBundleIdentifier"] as? String).map { bundleID in
                bundleID.split(separator: ".").dropLast().last.map(String.init) ?? ""
            }
            ?? ""
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 512, height: 512)
        return ImportedAppInfo(
            url: url,
            title: name,
            developer: Self.cleanedDeveloper(developer),
            version: version,
            bundleIdentifier: info?["CFBundleIdentifier"] as? String,
            icon: icon
        )
    }

    private static func cleanedDeveloper(_ value: String) -> String {
        var text = value
        if let range = text.range(of: "Copyright", options: .caseInsensitive) {
            text = String(text[range.upperBound...])
        }
        text = text.replacingOccurrences(of: "©", with: "")
        text = text.replacingOccurrences(of: "All rights reserved.", with: "", options: .caseInsensitive)
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,-")))
        if text.count > 46 { text = String(text.prefix(46)) }
        return text
    }

    // MARK: - First-run showcase

    func seededShowcaseGames() -> [Game] {
        let specs: [ShowcaseSpec] = [
            .init(
                key: "eclipse",
                title: "Eclipse Protocol",
                tagline: "当白昼熄灭，协议启动",
                overview: "一次失败的行星改造让殖民地陷入永夜。你是第七码头的信号官，在日蚀的阴影下追踪一段来自恒星深处的异常广播。每一次跃迁，都会让真相离你更近，也让归途更远。",
                developer: "Northstar Atelier",
                publisher: "Lumen Showcase",
                genre: "科幻 · 动作冒险",
                releaseYear: "2026",
                accent: "#F0A15C"
            ),
            .init(
                key: "neon",
                title: "Neon Reverie",
                tagline: "在永不熄灯的城市里做梦",
                overview: "霓虹市从不睡去。驾驶你的悬浮车穿过雨幕、天台与数据洪流，把这座城市的秘密一帧一帧拼起来。速度是你的语言，夜色是你的同谋。",
                developer: "Afterglow Studio",
                publisher: "Lumen Showcase",
                genre: "赛博朋克 · 竞速",
                releaseYear: "2025",
                accent: "#FF5EB8"
            ),
            .init(
                key: "verdant",
                title: "Verdant",
                tagline: "森林记得每一个名字",
                overview: "在最后一棵古树沉睡之前，循着萤火走进苔原深处。这里没有地图，只有风、月光和低语。你留下的每一条足迹，都会长成新的路径。",
                developer: "Moss & Moon",
                publisher: "Lumen Showcase",
                genre: "奇幻 · 探索",
                releaseYear: "2026",
                accent: "#D7E7A8"
            )
        ]

        var games: [Game] = []
        for (index, spec) in specs.enumerated() {
            let id = UUID()
            let hero = copyBundledImage(named: "showcase-\(spec.key)-hero", for: id, kind: .hero)
            let icon = copyBundledImage(named: "showcase-\(spec.key)-icon", for: id, kind: .icon)
            guard hero != nil || icon != nil else { continue }
            var game = Game(
                id: id,
                title: spec.title,
                tagline: spec.tagline,
                overview: spec.overview,
                developer: spec.developer,
                publisher: spec.publisher,
                genre: spec.genre,
                releaseYear: spec.releaseYear,
                appPath: "",
                iconPath: icon,
                heroPath: hero,
                accentHex: spec.accent,
                isShowcase: true,
                addedAt: Date().addingTimeInterval(TimeInterval(-index * 86_400)),
                sortOrder: index
            )
            game.launchCount = 0
            games.append(game)
        }
        return games
    }

    private func copyBundledImage(named name: String, for id: UUID, kind: MediaKind) -> String? {
        guard let source = Bundle.main.url(forResource: name, withExtension: "png") else {
            print("Lumen: missing showcase asset \(name)")
            return nil
        }
        return try? copyMedia(from: source, for: id, kind: kind)
    }

    struct ShowcaseSpec {
        let key: String
        let title: String
        let tagline: String
        let overview: String
        let developer: String
        let publisher: String
        let genre: String
        let releaseYear: String
        let accent: String
    }
}

final class ArtworkCache {
    static let shared = ArtworkCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 64
    }

    func image(at path: String?) -> NSImage? {
        guard let path, !path.isEmpty else { return nil }
        let key = path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard FileManager.default.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func image(at url: URL?) -> NSImage? {
        image(at: url?.path)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
