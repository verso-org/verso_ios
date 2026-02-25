import SwiftUI

struct GlassmorphicModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderOpacity: Double = 0.08
    var showShadow: Bool = true
    var glowColor: Color = .versoJade
    var glowIntensity: Double = 0

    func body(content: Content) -> some View {
        content
            .background(Color.versoCard.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(showShadow ? 0.25 : 0), radius: 8, y: 4)
    }
}

extension View {
    func glassmorphic(
        cornerRadius: CGFloat = 20,
        borderOpacity: Double = 0.08,
        showShadow: Bool = true,
        glowColor: Color = .versoJade,
        glowIntensity: Double = 0
    ) -> some View {
        modifier(GlassmorphicModifier(
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity,
            showShadow: showShadow,
            glowColor: glowColor,
            glowIntensity: glowIntensity
        ))
    }
}
