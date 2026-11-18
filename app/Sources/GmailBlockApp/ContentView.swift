import SwiftUI

public struct ContentView: View {
    @Bindable var viewModel: BlockViewModel

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
            .padding(.horizontal, 24).padding(.vertical, 12)
            Picker("Section", selection: $viewModel.section) {
                ForEach(AppSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .padding(.horizontal, 24).padding(.bottom, 12)
            .disabled(viewModel.isBusy)
            Divider()
            Group {
                switch viewModel.section {
                case .block: BlockView(viewModel: viewModel)
                case .offenders: OffenderView(viewModel: viewModel)
                case .blocked: BlockedView(viewModel: viewModel)
                }
            }
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
        .frame(minWidth: 540, minHeight: 500)
        .background(.background)
    }
}

/// Shared by the progress screens of every section.
func progressView(_ title: String, detail: String) -> some View {
    VStack(spacing: 14) {
        ProgressView().controlSize(.regular)
        Text(title).font(.headline)
        Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
            .frame(maxWidth: 360)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
}
