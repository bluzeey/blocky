import AppKit
import SwiftUI

struct MenuBarStatusIcon: View {
    let alignment: Alignment

    var body: some View {
        Image(nsImage: MenuBarStatusIconRenderer.image(for: alignment))
    }
}

private enum MenuBarStatusIconRenderer {
    static func image(for alignment: Alignment) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let center = CGPoint(x: 9, y: 9)
        let ringRect = CGRect(x: 2.5, y: 2.5, width: 13, height: 13)
        let innerRect = CGRect(x: 6.0, y: 6.0, width: 6, height: 6)
        let accentPath = NSBezierPath()
        accentPath.move(to: CGPoint(x: center.x, y: 1.5))
        accentPath.line(to: CGPoint(x: center.x, y: 4.0))

        NSColor.labelColor.setStroke()
        let outerRing = NSBezierPath(ovalIn: ringRect)
        outerRing.lineWidth = 1.6
        outerRing.stroke()

        let innerRing = NSBezierPath(ovalIn: innerRect)
        innerRing.lineWidth = 1.6
        innerRing.stroke()

        accentPath.lineWidth = 1.8
        accentPath.lineCapStyle = .round
        accentPath.stroke()

        let statusDotRect = CGRect(x: 13.2, y: 11.8, width: 3.6, height: 3.6)
        let statusDot = NSBezierPath(ovalIn: statusDotRect)
        statusColor(for: alignment).setFill()
        statusDot.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func statusColor(for alignment: Alignment) -> NSColor {
        switch alignment {
        case .aligned:
            return .systemGreen
        case .drift:
            return .systemRed
        case .sensitive:
            return .systemOrange
        case .neutral, .unknown:
            return .systemYellow
        }
    }
}
