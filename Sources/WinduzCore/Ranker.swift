import Foundation

public struct ScoredEntry {
    public let name: String
    public let path: String
    public let score: Double
    public let isFavorite: Bool
}

public enum Ranker {
    /// Favorites get this bonus added to their visit score — roughly equivalent
    /// to visiting once a day for a week, so pinned dirs stay visible even when
    /// you haven't cd'd there recently.
    public static let favoriteBoost: Double = 7.0

    public static func unifiedList(limit: Int = 30) -> [ScoredEntry] {
        let favorites = Store.shared.loadRaw()
        let favPaths = Set(favorites.map { $0.path })

        // Score map from visit history
        let visitScores = Dictionary(uniqueKeysWithValues: VisitLog.shared.topPaths(limit: 100))

        var entries: [ScoredEntry] = []

        // All favorites, with boost
        for fav in favorites {
            let score = (visitScores[fav.path] ?? 0) + favoriteBoost
            entries.append(ScoredEntry(name: fav.name, path: fav.path, score: score, isFavorite: true))
        }

        // Top visited dirs that are not favorites
        for (path, score) in VisitLog.shared.topPaths(limit: 50) {
            guard !favPaths.contains(path) else { continue }
            let name = (path as NSString).lastPathComponent
            entries.append(ScoredEntry(name: name, path: path, score: score, isFavorite: false))
        }

        return entries
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
}
