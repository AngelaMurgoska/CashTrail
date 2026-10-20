import SwiftUI
import UIKit

extension Color {
    /// Hero gradient endpoints. Darker than the app icon's so white text stays readable on them.
    static let lagoon = Color(red: 0.051, green: 0.580, blue: 0.533)   // #0D9488
    static let deepBlue = Color(red: 0.114, green: 0.306, blue: 0.847) // #1D4ED8

    /// The app accent: a deep teal in light mode (readable on white),
    /// a brighter one in dark mode.
    static let brandAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1) // #2DD4BF
            : UIColor(red: 0.059, green: 0.463, blue: 0.431, alpha: 1) // #0F766E
    })
}

extension ShapeStyle where Self == LinearGradient {
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [.lagoon, .deepBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A rounded panel whose bottom edge is a zigzag, like a torn-off receipt.
struct ReceiptShape: Shape {
    var cornerRadius: CGFloat = 24
    var toothWidth: CGFloat = 14
    var toothHeight: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bottom = rect.maxY - toothHeight

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))

        // Zigzag from right to left along the bottom edge.
        let teeth = max(1, Int((rect.width / toothWidth).rounded()))
        let step = rect.width / CGFloat(teeth)
        var x = rect.maxX
        for _ in 0..<teeth {
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            x -= step
            path.addLine(to: CGPoint(x: x, y: bottom))
        }

        path.closeSubpath()
        return path
    }
}
