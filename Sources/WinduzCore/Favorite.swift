import Foundation

public struct Favorite: Codable, Equatable {
    public var name: String
    public var path: String
    public var lastUsed: Date?

    public init(name: String, path: String, lastUsed: Date? = nil) {
        self.name = name
        self.path = path
        self.lastUsed = lastUsed
    }
}
