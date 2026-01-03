import Foundation

public struct AzureADGroup: Identifiable, Codable, Equatable {
    public let id: String
    public let displayName: String?
    public init(id: String, displayName: String?) {
        self.id = id
        self.displayName = displayName
    }
} 