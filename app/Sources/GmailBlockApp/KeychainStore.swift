import Foundation
import Security

/// Stores the Google service-account key in the macOS login (file-based) keychain.
/// Reads are done by Apple's /usr/bin/security (see the engine), so the item's
/// access list trusts this app and that tool; no prompt survives app rebuilds.
enum KeychainStore {
    static let service = "uk.magrathean.gmail-nuker"
    static let account = "service-account"
    static let label = "Gmail Nuker service account"
    private static let securityTool = "/usr/bin/security"

    enum StoreError: LocalizedError {
        case invalidKey(String)
        case keychain
        var errorDescription: String? {
            switch self {
            case .invalidKey(let message): message
            case .keychain: "The key could not be saved to your login keychain. Unlock it and try again."
            }
        }
    }

    private static func loginKeychain() -> SecKeychain? {
        guard let path = loginKeychainPath() else { return nil }
        var keychain: SecKeychain?
        return SecKeychainOpen(path, &keychain) == errSecSuccess ? keychain : nil
    }

    /// Identifies the item, restricted to the login keychain so another keychain cannot answer.
    private static var query: [String: Any] {
        var result: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: service,
                                     kSecAttrAccount as String: account]
        if let login = loginKeychain() { result[kSecMatchSearchList as String] = [login] }
        return result
    }

    /// Path of the login keychain for `security`, or nil to use its default search list.
    private static func loginKeychainPath() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityTool)
        process.arguments = ["login-keychain"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return nil }
        let path = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"").union(.whitespacesAndNewlines))
        return path.hasPrefix("/") ? path : nil
    }

    /// Metadata only (no secret data requested), so this never prompts.
    /// Returns nil when no item exists, otherwise the stored client_email (possibly empty).
    static func lookup() -> String? {
        var request = query
        request[kSecReturnAttributes as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let attributes = item as? [String: Any] else { return nil }
        return attributes[kSecAttrComment as String] as? String ?? ""
    }

    static var exists: Bool { lookup() != nil }

    /// Validates the JSON, re-serialises it compactly and stores it, replacing any previous item.
    /// `expectedEmail` may be empty. Returns the key's client_email.
    @discardableResult
    static func store(json data: Data, expectedEmail: String) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "service_account",
              let key = object["private_key"] as? String, !key.isEmpty,
              let email = object["client_email"] as? String, !email.isEmpty else {
            throw StoreError.invalidKey("That is not a Google service-account JSON key.")
        }
        if !expectedEmail.isEmpty, email != expectedEmail {
            throw StoreError.invalidKey("This key belongs to a different service account than the one configured.")
        }
        guard let compact = try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]) else {
            throw StoreError.invalidKey("That is not a Google service-account JSON key.")
        }
        if lookup() != nil {
            // Rotate in place so a failure cannot lose the working key; the access list is kept.
            let changes: [String: Any] = [kSecValueData as String: compact, kSecAttrComment as String: email]
            guard SecItemUpdate(query as CFDictionary, changes as CFDictionary) == errSecSuccess else { throw StoreError.keychain }
            return email
        }
        var access: SecAccess?
        var selfApp: SecTrustedApplication?
        var tool: SecTrustedApplication?
        guard SecTrustedApplicationCreateFromPath(nil, &selfApp) == errSecSuccess,
              SecTrustedApplicationCreateFromPath(securityTool, &tool) == errSecSuccess,
              let selfApp, let tool,
              SecAccessCreate(label as CFString, [selfApp, tool] as CFArray, &access) == errSecSuccess,
              let access, let login = loginKeychain() else { throw StoreError.keychain }
        var attributes = query
        attributes.removeValue(forKey: kSecMatchSearchList as String)
        attributes[kSecUseKeychain as String] = login
        attributes[kSecAttrLabel as String] = label
        attributes[kSecAttrComment as String] = email
        attributes[kSecAttrAccess as String] = access
        attributes[kSecValueData as String] = compact
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw StoreError.keychain }
        return email
    }

    /// Deletes through Apple's tool from the login keychain. A missing item (exit 44) counts as success.
    @discardableResult
    static func remove() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: securityTool)
        process.arguments = ["delete-generic-password", "-s", service, "-a", account] + (loginKeychainPath().map { [$0] } ?? [])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0 || process.terminationStatus == 44
    }
}
