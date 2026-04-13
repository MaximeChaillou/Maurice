import SwiftUI

// MARK: - Diff line

struct TemplateDiffLine: Hashable {
    enum Kind: Hashable {
        case same
        case added
        case removed

        var symbol: String {
            switch self {
            case .same: " "
            case .added: "+"
            case .removed: "-"
            }
        }

        var symbolColor: Color {
            switch self {
            case .same: .secondary.opacity(0.5)
            case .added: .green
            case .removed: .red
            }
        }

        var textColor: Color {
            switch self {
            case .same: .secondary
            case .added, .removed: .primary
            }
        }

        var background: Color {
            switch self {
            case .same: .clear
            case .added: Color.green.opacity(0.12)
            case .removed: Color.red.opacity(0.12)
            }
        }
    }

    let kind: Kind
    let content: String
}

struct TemplateDiffLineRow: View {
    let line: TemplateDiffLine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(line.kind.symbol)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(line.kind.symbolColor)
                .frame(width: 22, alignment: .center)
            Text(line.content.isEmpty ? " " : line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(line.kind.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(line.kind.background)
    }
}

// MARK: - Hunk + blocks

struct TemplateHunk: Identifiable, Hashable {
    let removedLines: [String]
    let addedLines: [String]

    var id: Int {
        var hasher = Hasher()
        for line in removedLines { hasher.combine(line) }
        hasher.combine("|")
        for line in addedLines { hasher.combine(line) }
        return hasher.finalize()
    }
}

enum TemplateDiffBlock {
    case context(TemplateDiffLine)
    case hunk(TemplateHunk)

    var isHunk: Bool {
        if case .hunk = self { return true }
        return false
    }

    static func group(lines: [TemplateDiffLine]) -> [TemplateDiffBlock] {
        var result: [TemplateDiffBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.kind == .same {
                result.append(.context(line))
                index += 1
                continue
            }
            var removed: [String] = []
            var added: [String] = []
            while index < lines.count, lines[index].kind != .same {
                switch lines[index].kind {
                case .removed: removed.append(lines[index].content)
                case .added: added.append(lines[index].content)
                case .same: break
                }
                index += 1
            }
            result.append(.hunk(TemplateHunk(removedLines: removed, addedLines: added)))
        }
        return result
    }
}

// MARK: - Diff computer

enum TemplateDiffComputer {
    static func unifiedDiff(
        old: [TemplateUpdateService.TaggedLine],
        new: [TemplateUpdateService.TaggedLine]
    ) -> [TemplateDiffLine] {
        let diff = new.difference(from: old)
        var removalOffsets = Set<Int>()
        var insertionDict: [Int: TemplateUpdateService.TaggedLine] = [:]
        for change in diff {
            switch change {
            case let .remove(offset, _, _):
                removalOffsets.insert(offset)
            case let .insert(offset, element, _):
                insertionDict[offset] = element
            }
        }

        var result: [TemplateDiffLine] = []
        var oldIdx = 0
        var newIdx = 0

        while oldIdx < old.count || newIdx < new.count {
            while oldIdx < old.count, removalOffsets.contains(oldIdx) {
                result.append(TemplateDiffLine(kind: .removed, content: old[oldIdx].display))
                oldIdx += 1
            }
            while let tagged = insertionDict[newIdx] {
                result.append(TemplateDiffLine(kind: .added, content: tagged.display))
                insertionDict.removeValue(forKey: newIdx)
                newIdx += 1
            }
            if oldIdx < old.count, newIdx < new.count,
               !removalOffsets.contains(oldIdx), insertionDict[newIdx] == nil {
                result.append(TemplateDiffLine(kind: .same, content: old[oldIdx].display))
                oldIdx += 1
                newIdx += 1
            } else if oldIdx >= old.count, newIdx >= new.count {
                break
            }
        }

        return result
    }
}
