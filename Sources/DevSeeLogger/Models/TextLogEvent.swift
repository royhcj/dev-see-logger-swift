import Foundation

public struct TextLogEvent: Codable, Sendable, Equatable {
    public let type: String
    public let text: String
    public let tags: [String]?

    public init(type: String = "text-log", text: String, tags: [String]? = nil) {
        self.type = type
        self.text = text
        self.tags = tags
    }
}
