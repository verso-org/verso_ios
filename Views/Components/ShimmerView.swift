import SwiftUI

/// A lightweight placeholder that pulses while content loads.
/// Uses a simple static fill — no animations to leak across navigation cycles.
struct ShimmerView: View {
    var body: some View {
        Rectangle()
            .fill(Color.versoCard)
    }
}
