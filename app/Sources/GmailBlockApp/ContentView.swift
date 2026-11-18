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
                Label(viewModel.account.usesKeychain ? "Key on this Mac" : "Key in 1Password", systemImage: "lock")
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

private enum CopyOutcome: Sendable {
    case key(Data), timedOut, failed
}

struct AccountSettingsView: View {
    @Bindable var viewModel: BlockViewModel
    @State private var mailbox = AccountConfiguration.load().mailbox
    @State private var secretReference = AccountConfiguration.load().secretReference
    @State private var source = AccountConfiguration.load().effectiveSource
    @State private var storedKey = KeychainStore.lookup()
    @State private var importing = false
    @State private var confirmRemoval = false
    @State private var keyMessage: String?
    @State private var copying = false

    private var hasReference: Bool {
        secretReference.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("op://")
    }

    var body: some View {
        Form {
            Section("Google Workspace") {
                TextField("Email address", text: $mailbox)
                Picker("Google key", selection: $source) {
                    Text("This Mac (Keychain)").tag("keychain")
                    Text("1Password").tag("1password")
                }
                if source == "keychain" { keychainControls } else { onePasswordControls }
            }
            Section {
                Button("Save & Check Connection") {
                    let defaults = UserDefaults.standard
                    defaults.set(mailbox.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "mailbox")
                    defaults.set(secretReference.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "secretReference")
                    defaults.set(source, forKey: "credentialSource")
                    viewModel.refreshAccount()
                    Task { await viewModel.checkConnection() }
                }.disabled(viewModel.isBusy || copying)
                if viewModel.isBusy { ProgressView().controlSize(.small) }
                if viewModel.connectionChecked { Label("Connected to Gmail", systemImage: "checkmark.circle") }
                if case .error(let message) = viewModel.currentPhase {
                    Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped).padding(12).frame(width: 520, height: 520)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in importKey(result) }
        .confirmationDialog("Remove the Google key from this Mac?", isPresented: $confirmRemoval) {
            Button("Remove Key", role: .destructive) { removeKey() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Gmail Nuker will stop working until you import a key again. The key in Google Cloud is not affected.")
        }
    }

    @ViewBuilder private var keychainControls: some View {
        if let email = storedKey {
            Label(email.isEmpty ? "Stored on this Mac" : "Stored on this Mac: \(email)", systemImage: "lock")
                .textSelection(.enabled)
        } else {
            Label("No key stored", systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
        }
        HStack {
            Button("Import JSON File…") { importing = true }.disabled(copying)
            if hasReference {
                Button("Copy from 1Password") { copyFromOnePassword() }.disabled(copying)
            }
            if storedKey != nil {
                Button("Remove from this Mac", role: .destructive) { confirmRemoval = true }.disabled(copying)
            }
            if copying { ProgressView().controlSize(.small) }
        }
        if let keyMessage {
            Text(keyMessage).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
        }
        Text("The key is kept in your login keychain and is never embedded in the app. Any program running as you can read it without a prompt while your Mac is unlocked, through Apple’s security tool.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder private var onePasswordControls: some View {
        TextField("1Password field", text: $secretReference)
        Text("Use the secret reference for the field containing your service-account JSON, such as op://Vault/Item/credential. Your key stays in 1Password, which asks for approval each time. Keep 1Password installed and enable Settings → Developer → Integrate with 1Password CLI.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func importKey(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            keyMessage = "That file could not be read."
            return
        }
        store(data, success: "Key stored on this Mac. You can now delete the downloaded JSON file.")
    }

    /// Keychain work can wait on an unlock prompt, so it runs off the main actor.
    private func store(_ data: Data, success: String) {
        let expected = AccountConfiguration.load().serviceAccount
        copying = true
        Task {
            let outcome = await Task.detached { () -> String? in
                do { try KeychainStore.store(json: data, expectedEmail: expected); return nil }
                catch { return error.localizedDescription }
            }.value
            let stored = await Task.detached { KeychainStore.lookup() }.value
            copying = false
            storedKey = stored
            if let outcome { keyMessage = outcome; return }
            source = "keychain"
            UserDefaults.standard.set("keychain", forKey: "credentialSource")
            keyMessage = success
            viewModel.refreshAccount()
        }
    }

    private func removeKey() {
        copying = true
        Task {
            let removed = await Task.detached { KeychainStore.remove() }.value
            let stored = await Task.detached { KeychainStore.lookup() }.value
            copying = false
            storedKey = stored
            keyMessage = removed ? "The key was removed from this Mac." : "The key could not be removed. Unlock your login keychain and try again."
            viewModel.refreshAccount()
        }
    }

    private func copyFromOnePassword() {
        let reference = secretReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = AccountConfiguration.load()
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/op")
        copying = true
        keyMessage = "Approve 1Password if prompted…"
        Task {
            let outcome = await Task.detached { () -> CopyOutcome in
                let process = Process()
                process.executableURL = helper
                process.arguments = ["read", reference]
                var environment = ProcessInfo.processInfo.environment
                if let directory = configuration.opConfigDirectory, !directory.isEmpty {
                    environment["OP_CONFIG_DIR"] = NSString(string: directory).expandingTildeInPath
                }
                process.environment = environment
                let output = Pipe()
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                guard (try? process.run()) != nil else { return .failed }
                // Bound the wait: terminate the helper if 1Password never answers.
                let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeout)
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                timeout.cancel()
                if process.terminationReason == .uncaughtSignal { return .timedOut }
                return process.terminationStatus == 0 ? .key(data) : .failed
            }.value
            copying = false
            let data: Data
            switch outcome {
            case .key(let value): data = value
            case .timedOut:
                keyMessage = "1Password approval timed out. Unlock 1Password and try again."
                return
            case .failed:
                keyMessage = "Could not read the key from 1Password. Unlock it and try again."
                return
            }
            store(data, success: "Key copied to this Mac. Gmail Nuker now uses it instead of 1Password.")
        }
    }
}
