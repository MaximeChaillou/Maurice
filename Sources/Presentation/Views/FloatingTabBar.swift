import SwiftUI

private struct TabItem {
    let tab: AppTab
    let label: String
    let icon: String
}

struct FloatingTabBar: View {
    @Binding var activeTab: AppTab
    var onSearchTap: () -> Void = {}

    @Namespace private var tabNamespace

    private let tabs: [TabItem] = [
        TabItem(tab: .meeting, label: "Réunions", icon: "calendar"),
        TabItem(tab: .people, label: "Personnes", icon: "person.2"),
        TabItem(tab: .task, label: "Tâches", icon: "checklist"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(tabs, id: \.tab) { item in
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            activeTab = item.tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(item.label)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if activeTab == item.tab {
                                Capsule()
                                    .fill(.white.opacity(0.15))
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(activeTab == item.tab ? .primary : .secondary)
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)

            Button {
                onSearchTap()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .glassEffect(.regular, in: .circle)
        }
    }
}
