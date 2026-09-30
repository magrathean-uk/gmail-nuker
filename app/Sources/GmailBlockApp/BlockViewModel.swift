import Foundation
import SwiftUI

public enum AppPhase: Sendable, Equatable {
    case input
    case blocking
    case checking
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
    var account = AccountConfiguration.load()
    public var connectionChecked = false
    public var operationError: String?

    private let service: BlockService

    public init(service: BlockService = BlockService()) {
        self.service = service
    }

    public func submitBlock() async {
        guard !isBusy else { return }
        let trimmed = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isBusy = true
        operationError = nil
        currentPhase = .blocking

        do {
            let result = try await service.executeBlock(target: trimmed, commit: true, purge: false, includeSpamTrash: true)
            isBusy = false
            currentPhase = .blockedPromptWipe(result)
        } catch {
            isBusy = false
            currentPhase = .error(error.localizedDescription)
        }
    }

    public func wipePrevious(result: BlockResult) async {
        guard !isBusy else { return }
        isBusy = true
        operationError = nil
        currentPhase = .purging(result)

        do {
            let purgeResult = try await service.deletePrevious(result: result)
            isBusy = false
            currentPhase = .finished(purgeResult, wasPurged: true)
        } catch {
            isBusy = false
            operationError = error.localizedDescription
            currentPhase = .blockedPromptWipe(result)
        }
    }

    public func keepPrevious(result: BlockResult) {
        currentPhase = .finished(result, wasPurged: false)
    }

    public func reset() {
        guard !isBusy else { return }
        targetText = ""
        currentPhase = .input
        isBusy = false
        operationError = nil
        account = AccountConfiguration.load()
    }

    func refreshAccount() {
        account = AccountConfiguration.load()
        connectionChecked = false
    }

    public func checkConnection() async {
        guard !isBusy else { return }
        isBusy = true
        operationError = nil
        currentPhase = .checking
        do {
            try await service.checkConnection()
            connectionChecked = true
            currentPhase = .input
        } catch {
            currentPhase = .error(error.localizedDescription)
        }
        isBusy = false
    }
}
