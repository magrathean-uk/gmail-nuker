import SwiftUI

/// Filters this tool made (sender mail goes to Trash), with a way to take one off.
struct BlockedView: View {
    @Bindable var viewModel: BlockViewModel
    @State private var pending: BlockedFilter?

    private var shown: [BlockedFilter] {
        let term = viewModel.blockedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return viewModel.blockedList }
        return viewModel.blockedList.filter { $0.from.localizedCaseInsensitiveContains(term) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Blocked Senders").font(.title2.weight(.semibold))
                    Text("Future mail from these senders goes to Trash.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { Task { await viewModel.loadBlocked() } }.disabled(viewModel.isBusy)
            }
            TextField("Search", text: $viewModel.blockedSearch).textFieldStyle(.roundedBorder)
            if let error = viewModel.blockedError {
                Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let message = viewModel.blockedMessage {
                Label(message, systemImage: "checkmark.circle").font(.callout).foregroundStyle(.secondary)
            }
            if viewModel.blockedLoading && viewModel.blockedList.isEmpty {
                progressView("Loading Blocked Senders", detail: "Reading your Gmail filters…")
            } else if shown.isEmpty {
                ContentUnavailableView(viewModel.blockedList.isEmpty ? "No Blocked Senders" : "No Matches", systemImage: "nosign")
                    .frame(maxHeight: .infinity)
            } else {
                List(shown) { filter in
                    HStack {
                        Text(filter.from).lineLimit(2).textSelection(.enabled)
                        Spacer()
                        Button("Unblock") { pending = filter }.disabled(viewModel.isBusy)
                    }.padding(.vertical, 3)
                }
                .listStyle(.inset).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task { if viewModel.account.isConfigured { await viewModel.loadBlocked() } }
        .alert("Unblock this sender?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { filter in
            Button("Cancel", role: .cancel) {}
            Button("Unblock") { Task { await viewModel.unblock(filter) } }
        } message: {
            Text("Unblock \($0.from)? Their future mail will arrive normally again. Mail already deleted stays deleted.")
        }
    }
}
