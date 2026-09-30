import Foundation

public struct TargetData: Sendable, Codable, Equatable {
    public let raw: String
    public let email: String?
    public let host: String
    public let root_domain: String
    public let block_mode: String
    public let is_public_provider: Bool
    public let is_multi_tenant_platform: Bool
}

public struct FoundMessage: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let threadId: String?
    public let from: String
    public let subject: String
    public let date: String
    public let list_unsubscribe: String?
    public let list_unsubscribe_post: String?
}

public struct BlockResult: Sendable, Codable, Equatable {
    public let success: Bool
    public let target: TargetData?
    public let committed: Bool?
    public let filter_id: String?
    public let already_active: Bool?
    public let found_messages: [FoundMessage]?
    public let purged: Int?
    public let remaining: Int?
    public let abuse_emails: [String]?
    public let registrar: String?
    public let safe_browsing_url: String?
    public let error: String?
}
