import Foundation

public extension Notification.Name {
    static let winduzFavoritesChanged = Notification.Name("winduzFavoritesChanged")
}

public enum StoreError: Error, CustomStringConvertible {
    case notFound(String)
    case duplicate(String)

    public var description: String {
        switch self {
        case .notFound(let s): return "not found: \(s)"
        case .duplicate(let s): return "already exists: \(s)"
        }
    }
}

public final class Store {
    public static let shared = Store()

    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let dir = appSupport.appendingPathComponent("Winduz", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("favorites.json")
        }
    }

    /// Raw load, preserving insertion order.
    public func loadRaw() -> [Favorite] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Favorite].self, from: data)) ?? []
    }

    /// Load with recently-used entries first. Never-used fall back to insertion order.
    public func load() -> [Favorite] {
        let favs = loadRaw()
        return favs.enumerated().sorted { a, b in
            switch (a.element.lastUsed, b.element.lastUsed) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map { $0.element }
    }

    public func save(_ favorites: [Favorite]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(favorites)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Update `lastUsed` for the favorite matching `path`, if any.
    public func touch(path: String) {
        var favs = loadRaw()
        guard let idx = favs.firstIndex(where: { $0.path == path }) else { return }
        favs[idx].lastUsed = Date()
        try? save(favs)
        NotificationCenter.default.post(name: .winduzFavoritesChanged, object: nil)
    }

    @discardableResult
    public func add(name: String, path: String) throws -> Favorite {
        var favs = loadRaw()
        if favs.contains(where: { $0.path == path }) {
            throw StoreError.duplicate(path)
        }
        if favs.contains(where: { $0.name == name }) {
            throw StoreError.duplicate(name)
        }
        let fav = Favorite(name: name, path: path)
        favs.append(fav)
        try save(favs)
        return fav
    }

    @discardableResult
    public func remove(matching query: String) throws -> Favorite {
        var favs = loadRaw()
        guard let idx = favs.firstIndex(where: { $0.name == query || $0.path == query }) else {
            throw StoreError.notFound(query)
        }
        let removed = favs.remove(at: idx)
        try save(favs)
        return removed
    }

    public func find(matching query: String) -> Favorite? {
        let favs = loadRaw()
        return favs.first(where: { $0.name == query || $0.path == query })
    }
}
