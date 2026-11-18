import Foundation

/// Offender list and blocked list actions. Each one holds the busy flag so the app cannot quit mid-way.
extension BlockViewModel {
    func scanInbox() async {
        guard !isBusy else { return }
        isBusy = true
        offenderPhase = .scanning
        do {
            offenderList = try await service.offenders(days: 30)
            selectedOffenders = []
            hasScanned = true
            offenderPhase = .idle
        } catch {
            offenderPhase = .error(error.localizedDescription)
        }
        isBusy = false
    }

    /// Blocks each selected sender in turn (exact address), then asks once before deleting anything.
    func blockSelectedOffenders() async {
        guard !isBusy else { return }
        let senders = offenderList.filter { selectedOffenders.contains($0.id) }.map(\.sender)
        guard !senders.isEmpty else { return }
        isBusy = true
        var previews: [SenderPreview] = []
        for (index, sender) in senders.enumerated() {
            offenderPhase = .blocking("Blocking \(index + 1) of \(senders.count): \(sender)")
            do {
                let result = try await service.executeBlock(target: sender, exact: true, commit: true, purge: false, includeSpamTrash: true)
                previews.append(SenderPreview(sender: sender, result: result, error: nil))
            } catch {
                previews.append(SenderPreview(sender: sender, result: nil, error: error.localizedDescription))
            }
        }
        isBusy = false
        if previews.contains(where: { $0.count > 0 }) {
            offenderPhase = .confirm(previews)
        } else {
            finishOffenders(previews, deleted: [:])
        }
    }

    func keepOffenderMail(_ previews: [SenderPreview]) { finishOffenders(previews, deleted: [:]) }

    /// Deletes per sender; one failure never hides the others' results.
    func deleteOffenderMail(_ previews: [SenderPreview]) async {
        guard !isBusy else { return }
        isBusy = true
        var deleted: [String: Result<Int, Error>] = [:]
        let targets = previews.filter { $0.result != nil && $0.count > 0 }
        for (index, preview) in targets.enumerated() {
            offenderPhase = .deleting("Deleting \(index + 1) of \(targets.count): \(preview.sender)")
            do {
                let outcome = try await service.deletePrevious(result: preview.result!)
                deleted[preview.sender] = .success(outcome.deleted_permanently ?? 0)
            } catch {
                deleted[preview.sender] = .failure(error)
            }
        }
        isBusy = false
        finishOffenders(previews, deleted: deleted)
    }

    private func finishOffenders(_ previews: [SenderPreview], deleted: [String: Result<Int, Error>]) {
        let outcomes = previews.map { preview -> SenderOutcome in
            if let error = preview.error {
                return SenderOutcome(sender: preview.sender, message: "Not blocked: \(error)", failed: true)
            }
            switch deleted[preview.sender] {
            case .success(let count):
                return SenderOutcome(sender: preview.sender, message: "Blocked; \(count) \(Self.messages(count)) permanently deleted", failed: false)
            case .failure(let error):
                return SenderOutcome(sender: preview.sender, message: "Blocked, but deletion failed: \(error.localizedDescription)", failed: true)
            case nil:
                return SenderOutcome(sender: preview.sender, message: preview.count > 0 ? "Blocked; \(preview.count) \(Self.messages(preview.count)) kept" : "Blocked; no existing mail", failed: false)
            }
        }
        let blocked = Set(previews.filter { $0.result != nil }.map(\.sender))
        offenderList.removeAll { blocked.contains($0.sender) }
        selectedOffenders.subtract(blocked)
        offenderPhase = .done(outcomes)
    }

    static func messages(_ count: Int) -> String { count == 1 ? "message" : "messages" }

    func loadBlocked() async {
        guard !isBusy else { return }
        isBusy = true
        blockedLoading = true
        blockedError = nil
        do { blockedList = try await service.listBlocked() }
        catch { blockedError = error.localizedDescription }
        blockedLoading = false
        isBusy = false
    }

    func unblock(_ filter: BlockedFilter) async {
        guard !isBusy else { return }
        isBusy = true
        blockedError = nil
        blockedMessage = nil
        do {
            try await service.unblock(filterId: filter.filter_id)
            blockedMessage = "Unblocked \(filter.from)."
            blockedList = try await service.listBlocked()
        } catch {
            blockedError = error.localizedDescription
        }
        isBusy = false
    }
}
