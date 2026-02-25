import SwiftUI

struct StatusBadge: View {
    let status: Int

    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch status {
        case 1: return "Pending"
        case 2: return "Approved"
        case 3: return "Declined"
        case 4: return "Available"
        case 5: return "Available"
        default: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch status {
        case 1: return .statusPending
        case 2: return .statusApproved
        case 3: return .statusDeclined
        case 4, 5: return .statusAvailable
        default: return .secondary
        }
    }
}
