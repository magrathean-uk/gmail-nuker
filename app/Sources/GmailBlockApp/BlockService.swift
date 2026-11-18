import Foundation

public struct BlockService: Sendable {
    public let scriptPath: URL

    /// Packaged apps use their own engine/runtime, independent of the checkout.
    public static var defaultScriptPath: URL {
        let packaged = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Engine/gmail-nuker-engine")
        if FileManager.default.isExecutableFile(atPath: packaged.path) { return packaged }
        let beside = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("bin/gmail-block")
        if FileManager.default.isExecutableFile(atPath: beside.path) { return beside }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin/gmail-block")
    }

    /// GUI apps get a minimal PATH, so `env python3` would pick Apple's old Python; use the Homebrew one the engine needs.
    private static let python = URL(fileURLWithPath: "/opt/homebrew/bin/python3")

    public init(scriptPath: URL = BlockService.defaultScriptPath) {
        self.scriptPath = scriptPath
    }

    public func executeBlock(target: String, exact: Bool = false, commit: Bool = true, purge: Bool = false, includeSpamTrash: Bool = false) async throws -> BlockResult {
        var args = ["block", target, "--json"]
        if exact { args.append("--exact") }
        if commit {
            args.append("--commit")
        }
        if purge {
            args.append("--purge")
        }
        if includeSpamTrash {
            args.append("--include-spam-trash")
        }

        return try await runScript(args: args)
    }

    public func checkConnection() async throws {
        let _: BlockResult = try await runScript(args: ["check"])
    }

    public func listBlocked() async throws -> [BlockedFilter] {
        let result: BlockedListResult = try await runScript(args: ["list", "--json"])
        return result.blocked ?? []
    }

    /// Removes one filter (never touches mail) and requires the engine to confirm it is gone.
    public func unblock(filterId: String) async throws {
        let result: UnblockResult = try await runScript(args: ["unblock", filterId, "--json", "--commit"])
        guard result.committed == true, result.unblock_verified == true else {
            throw NSError(domain: "BlockService", code: 1, userInfo: [NSLocalizedDescriptionKey: "The engine did not confirm the filter was removed."])
        }
    }

    public func offenders(days: Int = 30) async throws -> [Offender] {
        let result: OffenderResult = try await runScript(args: ["offenders", "--json", "--days", String(days)])
        return result.offenders ?? []
    }

    public func deletePrevious(result: BlockResult) async throws -> BlockResult {
        guard let target = result.target, !result.allIDs.isEmpty else {
            throw NSError(domain: "BlockService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No messages were selected for deletion."])
        }
        var args = ["delete", target.raw, "--json", "--commit"]
        if target.block_mode == "exact" { args.append("--exact") }
        for id in result.allIDs { args += ["--message-id", id] }
        let deletion: BlockResult = try await runScript(args: args)
        guard deletion.delete_verified == true, deletion.remaining == 0 else {
            throw NSError(domain: "BlockService", code: 1, userInfo: [NSLocalizedDescriptionKey: "The engine did not verify permanent deletion. The incoming block remains active."])
        }
        return deletion
    }

    private func runScript<T: Decodable & Sendable>(args: [String]) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let isPackaged = self.scriptPath.lastPathComponent == "gmail-nuker-engine"
                if !isPackaged && FileManager.default.isExecutableFile(atPath: Self.python.path) {
                    process.executableURL = Self.python
                    process.arguments = [self.scriptPath.path] + args
                } else {
                    process.executableURL = self.scriptPath
                    process.arguments = args
                }
                if isPackaged {
                    var environment = ProcessInfo.processInfo.environment
                    environment.merge(AccountConfiguration.load().environment) { _, new in new }
                    // Never inherit an old file credential from a Terminal launcher.
                    environment.removeValue(forKey: "GMAIL_BLOCK_SA")
                    environment.removeValue(forKey: "GMAIL_SMTP_CREDS")
                    process.environment = environment
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    // Drain both streams concurrently: a full pipe must not stall
                    // the child while this thread waits for process termination.
                    let stdout = ProcessOutput()
                    let stderr = ProcessOutput()
                    let readers = DispatchGroup()
                    for (pipe, output) in [(stdoutPipe, stdout), (stderrPipe, stderr)] {
                        readers.enter()
                        DispatchQueue.global(qos: .userInitiated).async {
                            output.store(pipe.fileHandleForReading.readDataToEndOfFile())
                            readers.leave()
                        }
                    }
                    process.waitUntilExit()
                    readers.wait()
                    let stdoutData = stdout.read()
                    let stderrData = stderr.read()

                    if !stdoutData.isEmpty {
                        let decoder = JSONDecoder()
                        let envelope = try decoder.decode(Envelope.self, from: stdoutData)
                        guard envelope.success else {
                            throw NSError(
                                domain: "BlockService",
                                code: Int(process.terminationStatus == 0 ? 1 : process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: envelope.error ?? "The mail operation failed."]
                            )
                        }
                        guard process.terminationStatus == 0 else {
                            let stderrMessage = String(data: stderrData, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            let message = stderrMessage.flatMap { $0.isEmpty ? nil : $0 }
                                ?? "Mail engine exited with code \(process.terminationStatus)."
                            throw NSError(
                                domain: "BlockService",
                                code: Int(process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: message]
                            )
                        }
                        continuation.resume(returning: try decoder.decode(T.self, from: stdoutData))
                    } else {
                        let errString = String(data: stderrData, encoding: .utf8) ?? "Process exited with code \(process.terminationStatus)"
                        continuation.resume(throwing: NSError(domain: "BlockService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errString]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private struct Envelope: Decodable {
    let success: Bool
    let error: String?
}

/// A single writer and reader transfer process output across GCD queues.
/// All access is protected by the lock; no mutable state escapes it.
private final class ProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func store(_ value: Data) { lock.withLock { data = value } }
    func read() -> Data { lock.withLock { data } }
}
