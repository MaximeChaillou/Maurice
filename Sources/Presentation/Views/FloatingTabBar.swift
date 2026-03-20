import SwiftUI

private struct TabItem {
    let tab: AppTab
    let label: LocalizedStringKey
    let icon: String
}

struct FloatingTabBar: View {
    @Binding var activeTab: AppTab
    var isHomeActive: Bool = false
    var onHomeTap: () -> Void = {}
    var onTabTap: () -> Void = {}
    var onSearchTap: () -> Void = {}

    @Namespace private var tabNamespace

    private let tabs: [TabItem] = [
        TabItem(tab: .meeting, label: "Meetings", icon: "calendar"),
        TabItem(tab: .people, label: "People", icon: "person.2"),
        TabItem(tab: .task, label: "Tasks", icon: "checklist"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onHomeTap()
            } label: {
                Image(systemName: "house")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background {
                        if isHomeActive {
                            Circle()
                                .fill(.white.opacity(0.15))
                        }
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHomeActive ? .primary : .secondary)
            .glassEffect(.regular, in: .circle)
            .help("Home")

            HStack(spacing: 4) {
                ForEach(tabs, id: \.tab) { item in
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            activeTab = item.tab
                        }
                        onTabTap()
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
                            if !isHomeActive && activeTab == item.tab {
                                Capsule()
                                    .fill(.white.opacity(0.15))
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(!isHomeActive && activeTab == item.tab ? .primary : .secondary)
                    .help(Text(item.label))
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
            .help("Search (⌘⇧F)")
        }
    }
}
