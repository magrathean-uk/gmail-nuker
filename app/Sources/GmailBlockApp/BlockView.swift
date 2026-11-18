import SwiftUI

/// The original single-sender flow: block, preview, then a separate confirmation before permanent deletion.
struct BlockView: View {
    @Bindable var viewModel: BlockViewModel
    @FocusState private var targetFocused: Bool
    @State private var showDeletionConfirmation = false

    var body: some View {
        phaseContent
            .onAppear { targetFocused = true }
            .onChange(of: viewModel.currentPhase) { _, phase in
                if phase == .input { targetFocused = true }
            }
    }

    @ViewBuilder private var phaseContent: some View {
        switch viewModel.currentPhase {
        case .input: inputView
        case .blocking:
            progress("Blocking Sender", detail: "Approve 1Password if prompted (not needed for a key on this Mac). Creating the filter and finding matching mail…")
        case .checking:
            progress("Connecting to Gmail", detail: "Approve 1Password if prompted (not needed for a key on this Mac). Checking access to your mailbox…")
        case .blockedPromptWipe(let result): preview(result)
        case .purging:
            progress("Deleting Messages", detail: "Permanently deleting the confirmed messages and verifying their removal…")
        case .finished(let result, let deleted): finished(result, deleted: deleted)
        case .error(let message):
            VStack(alignment: .leading, spacing: 16) {
                Label("Couldn’t Complete the Request", systemImage: "exclamationmark.circle")
                    .font(.title3.weight(.semibold))
                Text(message).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                HStack {
                    SettingsLink { Text("Account Settings…") }
                    Spacer()
                    Button("Try Again") { viewModel.reset() }.keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Block Unwanted Mail").font(.title2.weight(.semibold))
                Text("Send future mail from a sender or domain to Trash, and optionally delete their whole history.")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Email address or domain").font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    TextField("sender@example.com", text: $viewModel.targetText)
                        .textFieldStyle(.roundedBorder)
                        .focused($targetFocused)
                        .onSubmit { if canBlock { Task { await viewModel.submitBlock() } } }
                        .accessibilityLabel("Email address or domain")
                    Button("Block") { Task { await viewModel.submitBlock() } }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction).disabled(!canBlock)
                }.controlSize(.large)
            }
            Text("Company addresses block the whole domain. Shared email providers use the exact address. Blocking also attempts supported unsubscribe requests.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if !viewModel.account.isConfigured {
                SettingsLink { Text("Set Up Account…") }.buttonStyle(.borderedProminent)
            }
        }
    }

    private var canBlock: Bool {
        !viewModel.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.account.isConfigured && !viewModel.isBusy
    }

    private func progress(_ title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.regular)
            Text(title).font(.headline)
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func targetName(_ result: BlockResult) -> String {
        guard let target = result.target else { return viewModel.targetText }
        return target.block_mode == "exact" ? (target.email ?? target.host) : target.root_domain
    }

    private func preview(_ result: BlockResult) -> some View {
        let messages = result.found_messages ?? []
        let total = max(result.total, messages.count)
        let totalText = result.truncated ? "at least \(total)" : "\(total)"
        let noun = BlockViewModel.messages(total)
        let target = targetName(result)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(result.already_active == true ? "Sender Already Blocked" : "Sender Blocked", systemImage: "checkmark.circle")
                    .font(.title3.weight(.semibold))
                Text("Future mail from \(target) goes to Trash.")
                    .foregroundStyle(.secondary).textSelection(.enabled)
            }
            if total == 0 {
                ContentUnavailableView("No Matching Mail", systemImage: "tray", description: Text("No existing messages were found in this search."))
            } else {
                HStack {
                    Text("\(totalText) matching \(noun)").font(.headline)
                    Spacer()
                    Text("Includes Spam & Trash").font(.caption).foregroundStyle(.secondary)
                }
                List(messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.subject.isEmpty ? "(No Subject)" : message.subject)
                            .font(.body.weight(.medium)).lineLimit(2)
                        HStack {
                            Text(message.from).lineLimit(1)
                            Spacer()
                            Text(message.date).lineLimit(1)
                        }.font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                .listStyle(.inset).frame(minHeight: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(result.truncated
                     ? "Showing the first \(messages.count). Delete removes the \(total) found so far; run it again for any that remain."
                     : "Showing the first \(messages.count). Delete removes all \(total) of them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = viewModel.operationError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer(minLength: 0)
            HStack {
                Button(total == 0 ? "Done" : "Keep Messages") { viewModel.keepPrevious(result: result) }
                    .keyboardShortcut(.defaultAction)
                Spacer()
                if total > 0 {
                    Button("Delete Permanently…", role: .destructive) { showDeletionConfirmation = true }
                }
            }
        }
        .alert("Delete \(totalText) \(noun) Permanently?", isPresented: $showDeletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) { Task { await viewModel.wipePrevious(result: result) } }
        } message: {
            Text("\(totalText.capitalizedFirst) \(noun) from \(target), including Spam and Trash, will be permanently deleted from Gmail. This can’t be undone.")
        }
    }

    private func finished(_ result: BlockResult, deleted: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(.tint)
            Text(deleted ? "Messages Deleted" : "Sender Blocked").font(.title2.weight(.semibold))
            if deleted {
                Text("\(result.deleted_permanently ?? 0) permanently deleted · \(result.already_missing ?? 0) already absent")
                    .foregroundStyle(.secondary)
                Text("Removal verified in Gmail.").font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Existing messages were kept.").foregroundStyle(.secondary)
            }
            Text("Future mail from \(targetName(result)) goes to Trash.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Block Another Sender") { viewModel.reset() }
                .keyboardShortcut(.defaultAction).padding(.top, 8)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
