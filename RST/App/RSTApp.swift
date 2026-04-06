import SwiftUI

@main
struct RSTApp: App {
    @StateObject private var viewModel = RecorderViewModel()
    @State private var liveChunkOverlayController = LiveChunkOverlayController()

    var body: some Scene {
        WindowGroup {
            RecorderView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear {
                    liveChunkOverlayController.synchronize(with: viewModel)
                }
                .onChange(of: viewModel.isRecording) { _, _ in
                    liveChunkOverlayController.synchronize(with: viewModel)
                }
                .onDisappear {
                    liveChunkOverlayController.dismiss()
                }
        }
        .windowResizability(.contentSize)
    }
}
