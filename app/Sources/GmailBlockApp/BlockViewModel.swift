import Foundation
import SwiftUI

public enum AppPhase: Sendable, Equatable {
    case input
    case blocking
    case blockedPromptWipe(BlockResult)
    case purging(BlockResult)
    case finished(BlockResult, wasPurged: Bool)
    case error(String)
}

@Observable
@MainActor
public final class BlockViewModel {
    public var targetText: String = ""
    public var currentPhase: AppPhase = .input
    public var isBusy: Bool = false

    private let service: BlockService

    public init(service: BlockService = BlockService()) {
        self.service = service
    }

    public func submitBlock() async {
        let trimmed = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isBusy = true
        currentPhase = .blocking

        do {
            let result = try await service.executeBlock(target: trimmed, commit: true, purge: false)
            isBusy = false
            currentPhase = .blockedPromptWipe(result)
        } catch {
            isBusy = false
            currentPhase = .error(error.localizedDescription)
        }
    }

    public func wipePrevious(result: BlockResult) async {
        guard let target = result.target?.raw else { return }
        isBusy = true
        currentPhase = .purging(result)

        do {
            let purgeResult = try await service.executeBlock(target: target, commit: true, purge: true)
            isBusy = false
            currentPhase = .finished(purgeResult, wasPurged: true)
        } catch {
            isBusy = false
            currentPhase = .error(error.localizedDescription)
        }
    }

    public func keepPrevious(result: BlockResult) {
        currentPhase = .finished(result, wasPurged: false)
    }

    public func reset() {
        targetText = ""
        currentPhase = .input
        isBusy = false
    }
}
