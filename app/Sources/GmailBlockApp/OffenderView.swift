import SwiftUI

/// Scan the inbox for noisy senders, block several at once, and delete their mail after one confirmation.
struct OffenderView: View {
    @Bindable var viewModel: BlockViewModel

    var body: some View {
        switch viewModel.offenderPhase {
        case .idle: listView
        case .scanning:
            progressView("Scanning Inbox", detail: "Looking at the last 30 days of mail. Approve 1Password if prompted (not needed for a key on this Mac).")
        case .blocking(let text):
            progressView("Blocking Senders", detail: text)
        case .deleting(let text):
            progressView("Deleting Messages", detail: text)
        case .confirm(let previews): confirmation(previews)
        case .done(let outcomes): done(outcomes)
        case .error(let message):
            VStack(alignment: .leading, spacing: 16) {
                Label("Couldn’t Complete the Request", systemImage: "exclamationmark.circle")
                    .font(.title3.weight(.semibold))
                Text(message).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                Button("Back") { viewModel.offenderPhase = .idle }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Offender List").font(.title2.weight(.semibold))
                Text("Senders that sent you the most mail in the last 30 days.").foregroundStyle(.secondary)
            }
            if !viewModel.account.isConfigured {
                Spacer()
                SettingsLink { Text("Set Up Account…") }.buttonStyle(.borderedProminent)
            } else if viewModel.offenderList.isEmpty {
                ContentUnavailableView(viewModel.hasScanned ? "No Repeat Senders" : "Nothing Scanned Yet",
                                       systemImage: "tray",
                                       description: Text(viewModel.hasScanned ? "No sender has sent you more than one message." : "Scan your inbox to see who fills it."))
                    .frame(maxHeight: .infinity)
            } else {
                List(viewModel.offenderList) { offender in
                    Toggle(isOn: binding(for: offender)) { row(offender) }
                        .toggleStyle(.checkbox).padding(.vertical, 3)
                }
                .listStyle(.inset).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if viewModel.account.isConfigured {
                HStack {
                    Button(viewModel.hasScanned ? "Scan Again" : "Scan Inbox") { Task { await viewModel.scanInbox() } }
                        .disabled(viewModel.isBusy)
                    Spacer()
                    Button("Block Selected (\(viewModel.selectedOffenders.count))") { Task { await viewModel.blockSelectedOffenders() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedOffenders.isEmpty || viewModel.isBusy)
                }
            }
        }
    }

    private func binding(for offender: Offender) -> Binding<Bool> {
        Binding(get: { viewModel.selectedOffenders.contains(offender.id) },
                set: { on in
                    if on { viewModel.selectedOffenders.insert(offender.id) }
                    else { viewModel.selectedOffenders.remove(offender.id) }
                })
    }

    private func row(_ offender: Offender) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(offender.name.isEmpty ? offender.sender : offender.name).font(.body.weight(.medium)).lineLimit(1)
                Spacer()
                Text("\(offender.count) \(BlockViewModel.messages(offender.count))").font(.caption).foregroundStyle(.secondary)
            }
            if !offender.name.isEmpty {
                Text(offender.sender).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(offender.latest_subject.isEmpty ? "(No Subject)" : offender.latest_subject)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if offender.has_unsubscribe {
                Label("Unsubscribe header", systemImage: "envelope.badge").font(.caption2).foregroundStyle(.tint)
            }
        }
    }

    private func confirmation(_ previews: [SenderPreview]) -> some View {
        let deletable = previews.filter { $0.count > 0 }
        let total = deletable.reduce(0) { $0 + $1.count }
        let anyTruncated = deletable.contains { $0.result?.truncated == true }
        return VStack(alignment: .leading, spacing: 14) {
            Label("Permanently delete \(anyTruncated ? "at least " : "")\(total) \(BlockViewModel.messages(total)) from \(deletable.count) \(deletable.count == 1 ? "sender" : "senders")?",
                  systemImage: "exclamationmark.triangle")
                .font(.title3.weight(.semibold))
            Text("All of them are now blocked. Deleting removes their existing mail from Gmail, including Spam and Trash. This can’t be undone.")
                .foregroundStyle(.secondary)
            List(previews) { preview in
                HStack {
                    Text(preview.sender).lineLimit(1)
                    Spacer()
                    if let error = preview.error {
                        Text("Not blocked: \(error)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    } else {
                        Text("\(preview.result?.truncated == true ? "at least " : "")\(preview.count)").foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("Keep Mail") { viewModel.keepOffenderMail(previews) }.keyboardShortcut(.defaultAction)
                Spacer()
                Button("Delete", role: .destructive) { Task { await viewModel.deleteOffenderMail(previews) } }
            }
        }
    }

    private func done(_ outcomes: [SenderOutcome]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Finished", systemImage: "checkmark.circle").font(.title3.weight(.semibold))
            List(outcomes) { outcome in
                VStack(alignment: .leading, spacing: 2) {
                    Text(outcome.sender).font(.body.weight(.medium)).lineLimit(1)
                    Label(outcome.message, systemImage: outcome.failed ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }.padding(.vertical, 2)
            }
            .listStyle(.inset).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Done") { viewModel.offenderPhase = .idle }.keyboardShortcut(.defaultAction)
            }
        }
    }
}
