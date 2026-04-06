import AppKit
import SwiftUI

@MainActor
final class LiveChunkOverlayController {
    private var panel: LiveChunkOverlayPanel?

    func synchronize(with viewModel: RecorderViewModel) {
        if viewModel.isRecording {
            presentIfNeeded(using: viewModel)
        } else {
            dismiss()
        }
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func presentIfNeeded(using viewModel: RecorderViewModel) {
        if panel == nil {
            let overlayView = LiveChunkOverlayView(viewModel: viewModel)
            let host = NSHostingView(rootView: overlayView)
            let panel = LiveChunkOverlayPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 128),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = host
            self.panel = panel
        }

        guard let panel else {
            return
        }

        reposition(panel)
        panel.orderFrontRegardless()
    }

    private func reposition(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let horizontalMargin: CGFloat = 20
        let verticalMargin: CGFloat = 20

        let origin = CGPoint(
            x: visibleFrame.maxX - size.width - horizontalMargin,
            y: visibleFrame.minY + verticalMargin
        )
        panel.setFrameOrigin(origin)
    }
}

private final class LiveChunkOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct LiveChunkOverlayView: View {
    @ObservedObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Live Chunk")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            Text(viewModel.liveChunkTranscript)
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(width: 360, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
