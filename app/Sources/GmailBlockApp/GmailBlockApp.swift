import SwiftUI

@main
struct GmailBlockApp: App {
    @State private var viewModel = BlockViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
