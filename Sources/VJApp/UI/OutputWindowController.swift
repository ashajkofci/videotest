import AppKit
import MetalKit

final class OutputWindowController: NSWindowController {
    private let displayID: Int

    init(displayID: Int) {
        self.displayID = displayID
        let screen = NSScreen.screens.indices.contains(displayID) ? NSScreen.screens[displayID] : NSScreen.screens.first
        let window = NSWindow(
            contentRect: screen?.frame ?? .zero,
            styleMask: [.titled, .resizable, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Output"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let view = MTKView()
        _ = MetalRenderer(mtkView: view)
        window.contentView = view
    }

    required init?(coder: NSCoder) {
        nil
    }

    func goFullscreen() {
        window?.toggleFullScreen(nil)
    }
}
