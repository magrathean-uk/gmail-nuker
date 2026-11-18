import Foundation

struct AccountConfiguration: Codable, Sendable {
    var mailbox = ""
    var secretReference = ""
    var serviceAccount = ""
    var opConfigDirectory: String?
    /// "keychain" or "1password"; nil means choose by what is available.
    var credentialSource: String?

    static func load() -> AccountConfiguration {
        var result = AccountConfiguration()
        if let url = Bundle.main.url(forResource: "AccountConfiguration", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundled = try? JSONDecoder().decode(Self.self, from: data) {
            result = bundled
        }
        let defaults = UserDefaults.standard
        if result.mailbox.isEmpty {
            result.mailbox = ProcessInfo.processInfo.environment["GMAIL_BLOCK_USER"] ?? ""
        }
        if let value = defaults.string(forKey: "mailbox") { result.mailbox = value }
        if let value = defaults.string(forKey: "secretReference") { result.secretReference = value }
        if let value = defaults.string(forKey: "credentialSource") { result.credentialSource = value }
        return result
    }

    /// Saved choice if any; otherwise Keychain when a key is stored, then 1Password when a reference is set.
    var effectiveSource: String {
        if let credentialSource, ["keychain", "1password"].contains(credentialSource) { return credentialSource }
        if KeychainStore.exists { return "keychain" }
        return secretReference.hasPrefix("op://") ? "1password" : "keychain"
    }
    var usesKeychain: Bool { effectiveSource == "keychain" }

    var isConfigured: Bool {
        guard mailbox.contains("@") else { return false }
        if usesKeychain { return KeychainStore.exists }
        return secretReference.hasPrefix("op://") || ProcessInfo.processInfo.environment["GMAIL_BLOCK_SA"] != nil
    }
    var environment: [String: String] {
        var result = ["GMAIL_NUKER_MAILBOX": mailbox,
         "GMAIL_NUKER_SECRET_REFERENCE": secretReference,
         "GMAIL_NUKER_SERVICE_ACCOUNT": serviceAccount,
         "GMAIL_NUKER_CREDENTIAL_SOURCE": effectiveSource]
        if let opConfigDirectory, !opConfigDirectory.isEmpty {
            result["OP_CONFIG_DIR"] = NSString(string: opConfigDirectory).expandingTildeInPath
        }
        return result
    }
}
