import SwiftUI

public struct ContentView: View {
    @Bindable var viewModel: BlockViewModel
    @FocusState private var isFieldFocused: Bool

    public init(viewModel: BlockViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.top, 24)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

            Divider()

            contentSection
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 440, idealHeight: 480)
        .background(.background)
        .onAppear {
            isFieldFocused = true
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.slash.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.red.gradient)

            VStack(alignment: .leading, spacing: 3) {
                Text("Gmail Nuclear Blocker")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Root-level domain eradication & automated incoming trash routing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // ── Dynamic Content ───────────────────────────────────────────────────────

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.currentPhase {
        case .input:
            inputView

        case .blocking:
            statusProgressView(
                title: "Engaging Nuclear Block",
                subtitle: "Creating root-level trash filter in Gmail and probing mailbox…"
            )

        case .blockedPromptWipe(let result):
            blockedPromptWipeView(result: result)

        case .purging:
            statusProgressView(
                title: "Wiping Previous Emails",
                subtitle: "Purging previous messages from mailbox to Trash…"
            )

        case .finished(let result, let wasPurged):
            finishedView(result: result, wasPurged: wasPurged)

        case .error(let message):
            errorView(message: message)
        }
    }

    // ── 1. Input View ─────────────────────────────────────────────────────────

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Address or Domain")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Enter a spammer email address (e.g. user@spam.com) or root domain. Corporate domains are blocked at the root apex level.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .foregroundStyle(.secondary)

                    TextField("Paste email or domain here…", text: $viewModel.targetText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isFieldFocused)
                        .onSubmit {
                            Task {
                                await viewModel.submitBlock()
                            }
                        }

                    if !viewModel.targetText.isEmpty {
                        Button {
                            viewModel.targetText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                Button {
                    Task {
                        await viewModel.submitBlock()
                    }
                } label: {
                    Label("Block Target", systemImage: "bolt.shield.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(viewModel.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.green)
                    Text("Auto-routed directly to Trash permanently (auto-purged)")
                }
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(.blue)
                    Text("Bypasses Inbox and strips Unread / Priority notifications")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)

            Spacer()
        }
    }

    // ── 2. Progress View ──────────────────────────────────────────────────────

    private func statusProgressView(title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // ── 3. Blocked Confirmation & Wipe Prompt View ────────────────────────────

    private func blockedPromptWipeView(result: BlockResult) -> some View {
        let domain = result.target?.root_domain ?? "Target"
        let messages = result.found_messages ?? []

        return VStack(alignment: .leading, spacing: 18) {
            // Block Success Banner
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Root-Level Block Active: \(domain)")
                        .font(.headline.weight(.bold))
                    Text("Any incoming email from this domain will be destroyed immediately into Trash.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )

            // Wipe Decision
            if !messages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Previous Emails Found (\(messages.count))")
                            .font(.headline)

                        Spacer()

                        Text("Wipe them too?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(messages) { msg in
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(msg.subject.isEmpty ? "(No Subject)" : msg.subject)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)

                                        HStack(spacing: 8) {
                                            Text(msg.from)
                                                .lineLimit(1)
                                            Text("•")
                                            Text(msg.date.prefix(25))
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "envelope.fill")
                                        .foregroundStyle(.secondary.opacity(0.6))
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 160)

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.wipePrevious(result: result)
                            }
                        } label: {
                            Label("Yes, Wipe All \(messages.count) Emails", systemImage: "trash.fill")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)

                        Button {
                            viewModel.keepPrevious(result: result)
                        } label: {
                            Text("No, Keep Previous")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.top, 4)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("No previous emails from this sender were found in your mailbox.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        viewModel.reset()
                    } label: {
                        Text("Block Another Target")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.top, 10)
            }

            Spacer()
        }
    }

    // ── 4. Finished / Confirmation View ───────────────────────────────────────

    private func finishedView(result: BlockResult, wasPurged: Bool) -> some View {
        let domain = result.target?.root_domain ?? "Target"

        return VStack(spacing: 20) {
            Spacer()

            Image(systemName: wasPurged ? "trash.circle.fill" : "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(wasPurged ? .red : .blue)

            VStack(spacing: 6) {
                Text(wasPurged ? "Wipe Complete & Domain Blocked" : "Root Block Confirmed")
                    .font(.title2.weight(.bold))

                if wasPurged {
                    Text("Successfully trashed previous emails. Any new incoming emails from \(domain) will be incinerated into Trash.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    Text("Previous emails preserved. Any new incoming emails from \(domain) will be incinerated into Trash.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            Button {
                viewModel.reset()
                isFieldFocused = true
            } label: {
                Label("Block Another Target", systemImage: "plus")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    // ── 5. Error View ─────────────────────────────────────────────────────────

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Operation Encountered an Issue")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button("Try Again") {
                viewModel.reset()
                isFieldFocused = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }
}
