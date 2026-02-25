import SwiftUI

extension Color {
    // Core palette — deep cinema blacks
    static let versoJade = Color(red: 0.18, green: 0.78, blue: 0.53)
    static let versoSilver = Color(red: 0.70, green: 0.75, blue: 0.82)
    static let versoBackground = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let versoCard = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let versoCardBorder = Color(red: 0.12, green: 0.14, blue: 0.17)
    static let versoGlass = Color.white.opacity(0.06)
    static let versoNavBackground = Color(red: 0.01, green: 0.01, blue: 0.02)
    static let versoSecondaryText = Color(red: 0.50, green: 0.54, blue: 0.60)

    // Depth system — jade-tinted shadows for cinema glow
    static let versoDepthShadow = Color(red: 0.0, green: 0.12, blue: 0.08)
    static let versoAmbientGlow = Color(red: 0.10, green: 0.45, blue: 0.30)

    // Status
    static let statusApproved = Color.green
    static let statusPending = Color.orange
    static let statusDeclined = Color.red
    static let statusAvailable = Color.blue

    // Gradients
    static let versoGradient = LinearGradient(
        colors: [versoJade, versoSilver],
        startPoint: .leading,
        endPoint: .trailing
    )
}

enum VersoSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let section: CGFloat = 36
}
