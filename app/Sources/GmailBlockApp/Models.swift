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
    public let found_ids: [String]?
    public let found_total: Int?
    public let history_truncated: Bool?
    public let purged: Int?
    public let remaining: Int?
    public let deleted_permanently: Int?
    public let already_missing: Int?
    public let delete_verified: Bool?
    public let abuse_emails: [String]?
    public let registrar: String?
    public let safe_browsing_url: String?
    public let error: String?
}

extension BlockResult {
    /// Every matching message the engine found (whole history, up to its cap); falls back to the preview.
    public var allIDs: [String] { found_ids ?? (found_messages ?? []).map(\.id) }
    public var total: Int { found_total ?? allIDs.count }
    public var truncated: Bool { history_truncated == true }
}

public struct Offender: Sendable, Codable, Identifiable, Equatable {
    public let sender: String
    public let name: String
    public let count: Int
    public let has_unsubscribe: Bool
    public let latest_subject: String
    public var id: String { sender }
}

public struct OffenderResult: Sendable, Codable, Equatable {
    public let success: Bool
    public let days: Int?
    public let sampled: Int?
    public let offenders: [Offender]?
    public let error: String?
}

public struct BlockedFilter: Sendable, Codable, Identifiable, Equatable {
    public let filter_id: String
    public let from: String
    public let query: String
    public var id: String { filter_id }
}

public struct BlockedListResult: Sendable, Codable, Equatable {
    public let success: Bool
    public let blocked: [BlockedFilter]?
    public let error: String?
}

public struct UnblockResult: Sendable, Codable, Equatable {
    public let success: Bool
    public let committed: Bool?
    public let removed: [String]?
    public let unblock_verified: Bool?
    public let error: String?
}
