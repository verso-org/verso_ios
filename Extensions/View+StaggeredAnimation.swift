import SwiftUI

extension View {
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearanceModifier(index: index))
    }
}

private struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(
                    .spring(response: 0.45, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05)
                ) {
                    appeared = true
                }
            }
    }
}
