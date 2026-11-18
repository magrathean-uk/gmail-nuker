import SwiftUI
import ServiceManagement

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
    @State private var login = LoginItem.shared

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
            Section("Startup & Mail") {
                Toggle("Open at login", isOn: Binding(get: { login.isOn }, set: { login.set($0) }))
                if login.needsApproval {
                    Text("Approve Gmail Nuker in System Settings, General, Login Items.").font(.caption).foregroundStyle(.secondary)
                }
                if let error = login.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                LabeledContent("Block selected Mail sender", value: "⌃⌥⌘B")
                Text("Select a message in Mail and press the shortcut. The sender is blocked and their existing mail goes to Trash. Mail asks once to allow Gmail Nuker to control it.")
                    .font(.caption).foregroundStyle(.secondary)
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
        .formStyle(.grouped).padding(12).frame(width: 520, height: 640)
        .onAppear { login.refresh() }
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
