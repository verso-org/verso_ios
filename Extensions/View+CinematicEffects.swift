import SwiftUI

// MARK: - Multi-layer depth shadow (jade-tinted cinema shadows)

extension View {
    func depthShadow(elevation: CGFloat = 1.0) -> some View {
        self
            .shadow(color: .black.opacity(0.25 * elevation), radius: 6 * elevation, y: 4 * elevation)
    }

    func ambientGlow(color: Color = .versoJade, radius: CGFloat = 40, opacity: Double = 0.12) -> some View {
        self.background(
            color
                .opacity(opacity)
                .blur(radius: radius)
                .offset(y: 8)
        )
    }
}

// MARK: - Safe collection subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
