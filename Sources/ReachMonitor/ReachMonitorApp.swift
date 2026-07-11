import AppKit
import SwiftUI

@main
struct ReachMonitorApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
                .task { state.start() }
        } label: {
            let elapsed = state.menuBarElapsedText
            let img = Image(nsImage: state.menuBarIcon)
            if elapsed.isEmpty {
                img
            } else {
                HStack(spacing: 4) {
                    img
                    Text(elapsed)
                        .font(.system(size: 11, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

extension AppState {
    /// Renders a filled circle as a non-template NSImage so the menu bar
    /// shows it in colour rather than flattening it to monochrome.
    var menuBarIcon: NSImage {
        let diameter: CGFloat = 10
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { rect in
            let nsColor: NSColor
            switch self.status {
            case .checking:    nsColor = .systemGray
            case .unreachable: nsColor = .black
            case .reachable:   nsColor = self.isLinkWiFi ? .systemBlue : .systemRed
            }
            nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
