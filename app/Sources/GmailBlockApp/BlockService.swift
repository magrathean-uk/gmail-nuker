import Foundation

public struct BlockService: Sendable {
    public let scriptPath: URL

    /// The engine sits in `bin/gmail-block` next to `GmailBlock.app`; fall back to the standard checkout path.
    public static var defaultScriptPath: URL {
        let beside = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("bin/gmail-block")
        if FileManager.default.isExecutableFile(atPath: beside.path) { return beside }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bin/gmail-block")
    }

    /// GUI apps get a minimal PATH, so `env python3` would pick Apple's old Python; use the Homebrew one the engine needs.
    private static let python = URL(fileURLWithPath: "/opt/homebrew/bin/python3")

    public init(scriptPath: URL = BlockService.defaultScriptPath) {
        self.scriptPath = scriptPath
    }

    public func executeBlock(target: String, commit: Bool = true, purge: Bool = false) async throws -> BlockResult {
        var args = ["block", target, "--json"]
        if commit {
            args.append("--commit")
        }
        if purge {
            args.append("--purge")
        }

        return try await runScript(args: args)
    }

    private func runScript(args: [String]) async throws -> BlockResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                if FileManager.default.isExecutableFile(atPath: Self.python.path) {
                    process.executableURL = Self.python
                    process.arguments = [self.scriptPath.path] + args
                } else {
                    process.executableURL = self.scriptPath
                    process.arguments = args
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    if !stdoutData.isEmpty {
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(BlockResult.self, from: stdoutData)
                        continuation.resume(returning: result)
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
