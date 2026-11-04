import AppKit
import Foundation

struct Game: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var tagline: String
    var overview: String
    var developer: String
    var publisher: String
    var genre: String
    var releaseYear: String
    var version: String

    /// The user-selected `.app` bundle. Deliberately optional at the model level so
    /// people can curate metadata before assigning the executable.
    var appPath: String
    var iconPath: String?
    var heroPath: String?
    var posterPath: String?
    var trailerPath: String?
    var accentHex: String?

    var isFavorite: Bool
    var isShowcase: Bool
    var addedAt: Date
    var lastPlayedAt: Date?
    var launchCount: Int
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String = "",
        tagline: String = "",
        overview: String = "",
        developer: String = "",
        publisher: String = "",
        genre: String = "动作冒险",
        releaseYear: String = "",
        version: String = "",
        appPath: String = "",
        iconPath: String? = nil,
        heroPath: String? = nil,
        posterPath: String? = nil,
        trailerPath: String? = nil,
        accentHex: String? = nil,
        isFavorite: Bool = false,
        isShowcase: Bool = false,
        addedAt: Date = Date(),
        lastPlayedAt: Date? = nil,
        launchCount: Int = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.overview = overview
        self.developer = developer
        self.publisher = publisher
        self.genre = genre
        self.releaseYear = releaseYear
        self.version = version
        self.appPath = appPath
        self.iconPath = iconPath
        self.heroPath = heroPath
        self.posterPath = posterPath
        self.trailerPath = trailerPath
        self.accentHex = accentHex
        self.isFavorite = isFavorite
        self.isShowcase = isShowcase
        self.addedAt = addedAt
        self.lastPlayedAt = lastPlayedAt
        self.launchCount = launchCount
        self.sortOrder = sortOrder
    }

    var appURL: URL? {
        guard !appPath.isEmpty else { return nil }
        return URL(fileURLWithPath: appPath)
    }

    var hasPlayableApp: Bool {
        guard let appURL else { return false }
        return FileManager.default.fileExists(atPath: appURL.path)
    }

    var metadataLine: String {
        [releaseYear, genre, developer]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "  ·  ")
    }

    var lastPlayedLabel: String {
        guard let lastPlayedAt else { return "尚未启动" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastPlayedAt, relativeTo: Date())
    }

    static let placeholder = Game(
        title: "你的游戏",
        tagline: "YOUR COLLECTION",
        overview: "导入游戏 App，添加海报、图标和宣传片，打造属于你的次世代游戏大厅。",
        developer: "Lumen",
        publisher: "Lumen",
        genre: "游戏",
        releaseYear: "2026",
        isShowcase: true
    )
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .favorites: "收藏"
        case .recent: "最近"
        }
    }
}

struct ImportedAppInfo {
    let url: URL
    let title: String
    let developer: String
    let version: String
    let bundleIdentifier: String?
    let icon: NSImage?
}
