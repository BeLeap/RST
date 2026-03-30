import SwiftUI

@main
struct RSTApp: App {
    @StateObject private var viewModel = RecorderViewModel()

    var body: some Scene {
        WindowGroup {
            RecorderView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowResizability(.contentSize)
    }
}
