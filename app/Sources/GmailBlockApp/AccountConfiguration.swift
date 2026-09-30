import Foundation

struct AccountConfiguration: Codable, Sendable {
    var mailbox = ""
    var secretReference = ""
    var serviceAccount = ""
    var opConfigDirectory: String?

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
        return result
    }

    var isConfigured: Bool {
        mailbox.contains("@") && (secretReference.hasPrefix("op://")
            || ProcessInfo.processInfo.environment["GMAIL_BLOCK_SA"] != nil)
    }
    var environment: [String: String] {
        var result = ["GMAIL_NUKER_MAILBOX": mailbox,
         "GMAIL_NUKER_SECRET_REFERENCE": secretReference,
         "GMAIL_NUKER_SERVICE_ACCOUNT": serviceAccount]
        if let opConfigDirectory, !opConfigDirectory.isEmpty {
            result["OP_CONFIG_DIR"] = NSString(string: opConfigDirectory).expandingTildeInPath
        }
        return result
    }
}
