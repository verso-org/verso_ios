import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: VersoSpacing.lg) {
            PhaseAnimator([0, 1, 2]) { phase in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.versoJade)
                            .frame(width: 8, height: 8)
                            .scaleEffect(phase == index ? 1.5 : 0.6)
                            .opacity(phase == index ? 1.0 : 0.25)
                    }
                }
            } animation: { _ in
                .easeInOut(duration: 0.45)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.versoSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.versoBackground)
    }
}
