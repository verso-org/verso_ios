import SwiftUI

enum GradientDirection {
    case bottom
    case top
    case full
}

struct GradientOverlay: View {
    var direction: GradientDirection = .bottom
    var color: Color = .black
    var startOpacity: Double = 0
    var endOpacity: Double = 0.85

    var body: some View {
        switch direction {
        case .bottom:
            LinearGradient(
                colors: [color.opacity(startOpacity), color.opacity(endOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .top:
            LinearGradient(
                colors: [color.opacity(endOpacity), color.opacity(startOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .full:
            LinearGradient(
                colors: [
                    color.opacity(endOpacity * 0.6),
                    color.opacity(startOpacity),
                    color.opacity(endOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
