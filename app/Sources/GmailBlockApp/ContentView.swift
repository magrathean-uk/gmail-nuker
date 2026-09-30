import SwiftUI

public struct ContentView: View {
    @Bindable var viewModel: BlockViewModel
    @FocusState private var targetFocused: Bool
    @State private var showDeletionConfirmation = false

    public init(viewModel: BlockViewModel) { self.viewModel = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "envelope").foregroundStyle(.secondary)
                Text(viewModel.account.mailbox.isEmpty ? "Choose a Workspace account" : viewModel.account.mailbox)
                    .font(.subheadline).textSelection(.enabled)
                Spacer()
                if viewModel.connectionChecked {
                    Label("Connected", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            Divider()
            phaseContent
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            HStack {
                Label("Credentials in 1Password", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                SettingsLink { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless).help("Account Settings")
                    .accessibilityLabel("Account Settings")
                    .disabled(viewModel.isBusy)
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(minWidth: 520, minHeight: 440)
        .background(.background)
        .onAppear { targetFocused = true }
        .onChange(of: viewModel.currentPhase) { _, phase in
            if phase == .input { targetFocused = true }
        }
    }

    @ViewBuilder private var phaseContent: some View {
        switch viewModel.currentPhase {
        case .input: inputView
        case .blocking:
            progress("Blocking Sender", detail: "Approve 1Password if prompted. Creating the filter and finding matching mail…")
        case .checking:
            progress("Connecting to Gmail", detail: "Approve 1Password if prompted. Checking access to your mailbox…")
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
                Text("Send future mail from a sender or domain to Trash.")
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
        let target = targetName(result)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(result.already_active == true ? "Sender Already Blocked" : "Sender Blocked", systemImage: "checkmark.circle")
                    .font(.title3.weight(.semibold))
                Text("Future mail from \(target) goes to Trash.")
                    .foregroundStyle(.secondary).textSelection(.enabled)
            }
            if messages.isEmpty {
                ContentUnavailableView("No Matching Mail", systemImage: "tray", description: Text("No existing messages were found in this search."))
            } else {
                HStack {
                    Text("\(messages.count) matching \(messages.count == 1 ? "message" : "messages")").font(.headline)
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
                Text("This preview shows up to 50 messages. Delete affects only the messages shown.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = viewModel.operationError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer(minLength: 0)
            HStack {
                Button(messages.isEmpty ? "Done" : "Keep Messages") { viewModel.keepPrevious(result: result) }
                    .keyboardShortcut(.defaultAction)
                Spacer()
                if !messages.isEmpty {
                    Button("Delete Permanently…", role: .destructive) { showDeletionConfirmation = true }
                }
            }
        }
        .alert("Delete \(messages.count) \(messages.count == 1 ? "Message" : "Messages") Permanently?", isPresented: $showDeletionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) { Task { await viewModel.wipePrevious(result: result) } }
        } message: {
            Text("The \(messages.count) \(messages.count == 1 ? "message" : "messages") shown for \(target) will be permanently deleted from Gmail. This can’t be undone.")
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

struct AccountSettingsView: View {
    @Bindable var viewModel: BlockViewModel
    @State private var mailbox = AccountConfiguration.load().mailbox
    @State private var secretReference = AccountConfiguration.load().secretReference

    var body: some View {
        Form {
            Section("Google Workspace") {
                TextField("Email address", text: $mailbox)
                TextField("1Password field", text: $secretReference)
                Text("Use the secret reference for the field containing your service-account JSON, such as op://Vault/Item/credential. Your key stays in 1Password.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("Keep 1Password installed and enable Settings → Developer → Integrate with 1Password CLI.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Save & Check Connection") {
                    UserDefaults.standard.set(mailbox.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "mailbox")
                    UserDefaults.standard.set(secretReference.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "secretReference")
                    viewModel.refreshAccount()
                    Task { await viewModel.checkConnection() }
                }.disabled(viewModel.isBusy)
                if viewModel.isBusy { ProgressView().controlSize(.small) }
                if viewModel.connectionChecked { Label("Connected to Gmail", systemImage: "checkmark.circle") }
                if case .error(let message) = viewModel.currentPhase {
                    Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }.formStyle(.grouped).padding(12).frame(width: 480, height: 390)
    }
}
