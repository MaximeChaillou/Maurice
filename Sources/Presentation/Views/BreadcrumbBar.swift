import AppKit
import SwiftUI

// MARK: - Breadcrumb data types

struct BreadcrumbSibling: Identifiable {
    enum Leading {
        case emoji(String)
        case symbol(String)
        case initials(String, gradient: [Color])
        case none
    }

    let id: String
    let label: String
    var sub: String?
    var date: String?
    var leading: Leading = .none
    var active: Bool = false
}

struct BreadcrumbSiblingGroup: Identifiable {
    let id: String
    var title: String?
    let siblings: [BreadcrumbSibling]
}

struct BreadcrumbSegment: Identifiable {
    enum Kind {
        case folder
        case file
    }

    let id: String
    let label: String
    var kind: Kind = .folder
    var revealURL: URL?
    var popoverTitle: String?
    var emptyMessage: String?
    let groups: [BreadcrumbSiblingGroup]
    let onPick: (String) -> Void
}

// MARK: - Breadcrumb Bar

struct BreadcrumbBar: View {
    let segments: [BreadcrumbSegment]
    @State private var openSegmentID: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 2)

            ForEach(Array(segments.enumerated()), id: \.element.id) { idx, seg in
                if idx > 0 {
                    Text("/")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .opacity(0.5)
                }
                segmentButton(idx: idx, seg: seg)
            }
        }
    }

    private func segmentButton(idx: Int, seg: BreadcrumbSegment) -> some View {
        let isLast = idx == segments.count - 1
        let isOpen = openSegmentID == seg.id
        return Button {
            openSegmentID = isOpen ? nil : seg.id
        } label: {
            segmentLabel(seg: seg, isLast: isLast, isOpen: isOpen)
        }
        .buttonStyle(.plain)
        .help(seg.popoverTitle ?? seg.label)
        .contextMenu {
            if let url = seg.revealURL {
                Button {
                    Self.revealInFinder(url: url, kind: seg.kind)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
        }
        .popover(
            isPresented: Binding(
                get: { isOpen },
                set: { if !$0 { openSegmentID = nil } }
            ),
            arrowEdge: .bottom
        ) {
            BreadcrumbPopover(segment: seg) { key in
                openSegmentID = nil
                seg.onPick(key)
            }
        }
    }

    private func segmentLabel(seg: BreadcrumbSegment, isLast: Bool, isOpen: Bool) -> some View {
        HStack(spacing: 3) {
            Text(seg.label)
                .font(.system(
                    size: 11,
                    weight: isLast ? .semibold : .regular,
                    design: .monospaced
                ))
                .foregroundStyle(isLast ? Color.primary : Color.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            if isOpen {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.07))
            }
        }
        .contentShape(.rect(cornerRadius: 5))
    }

    private static func revealInFinder(url: URL, kind: BreadcrumbSegment.Kind) {
        switch kind {
        case .folder:
            _ = NSWorkspace.shared.open(url)
        case .file:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

// MARK: - Breadcrumb Popover

private struct BreadcrumbPopover: View {
    let segment: BreadcrumbSegment
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = segment.popoverTitle {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }

            if isEmpty {
                Text(segment.emptyMessage ?? String(localized: "No other items"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(segment.groups.enumerated()), id: \.element.id) { idx, group in
                            if let groupTitle = group.title {
                                Text(groupTitle.uppercased())
                                    .font(.system(size: 9.5, weight: .bold))
                                    .kerning(0.8)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, idx == 0 ? 4 : 8)
                                    .padding(.bottom, 4)
                            }
                            ForEach(group.siblings) { sibling in
                                siblingRow(sibling)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
    }

    private var isEmpty: Bool {
        segment.groups.allSatisfy(\.siblings.isEmpty)
    }

    private func siblingRow(_ sibling: BreadcrumbSibling) -> some View {
        Button {
            onPick(sibling.id)
        } label: {
            HStack(spacing: 9) {
                leadingView(for: sibling.leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(sibling.label)
                        .font(.system(
                            size: 11.5,
                            weight: sibling.active ? .semibold : .medium,
                            design: .monospaced
                        ))
                        .foregroundStyle(sibling.active ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    if let sub = sibling.sub, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if let date = sibling.date, !date.isEmpty {
                    Text(date)
                        .font(.system(size: 10.5, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(sibling.active ? Color.cyan : Color.secondary)
                }
                if sibling.active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.cyan)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if sibling.active {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan.opacity(0.14))
                }
            }
            .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func leadingView(for leading: BreadcrumbSibling.Leading) -> some View {
        switch leading {
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: 13))
                .frame(width: 18)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)
        case .initials(let initials, let gradient):
            Text(initials)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
        case .none:
            EmptyView()
        }
    }
}
