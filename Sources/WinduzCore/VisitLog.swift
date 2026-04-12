import Foundation

public struct Visit: Codable {
    public let path: String
    public let ts: Date
}

public final class VisitLog {
    public static let shared = VisitLog()

    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let dir = appSupport.appendingPathComponent("Winduz", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("visits.jsonl")
        }
    }

    public func append(path: String, at ts: Date = Date()) {
        let visit = Visit(path: path, ts: ts)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(visit) else { return }
        var line = data
        line.append(0x0A)  // \n

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: fileURL, options: .atomic)
        }
    }

    public func loadAll() -> [Visit] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var visits: [Visit] = []
        for line in content.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let v = try? decoder.decode(Visit.self, from: data) else { continue }
            visits.append(v)
        }
        return visits
    }

    /// Frecency: sum over visits of exp(-age_days / halflife_days).
    /// Returns paths ranked descending.
    public func topPaths(limit: Int = 20, halflifeDays: Double = 14) -> [(path: String, score: Double)] {
        let now = Date()
        var scores: [String: Double] = [:]
        for v in loadAll() {
            let ageDays = now.timeIntervalSince(v.ts) / 86400.0
            scores[v.path, default: 0] += exp(-ageDays / halflifeDays)
        }
        return scores
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}
