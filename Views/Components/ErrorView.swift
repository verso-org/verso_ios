import SwiftUI

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: VersoSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.versoSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VersoSpacing.xl)

            if let retryAction {
                Button(action: retryAction) {
                    Text("Retry")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, VersoSpacing.xl)
                        .padding(.vertical, VersoSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [.versoJade, .versoSilver],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.versoBackground)
    }
}
