import SwiftUI

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabAnimation

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("rectangle.stack.fill", "Library"),
        ("sparkles", "Discover")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? Color.versoJade : Color.versoSecondaryText.opacity(0.5))

                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selectedTab == index ? Color.versoJade : Color.versoSecondaryText.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.versoJade.opacity(0.08))
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.versoNavBackground.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .shadow(color: Color.versoJade.opacity(0.06), radius: 30, y: 5)
        .padding(.horizontal, VersoSpacing.xl)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)

                LibraryListView()
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)

                SearchView()
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)
            }

            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 8)
        }
    }
}
