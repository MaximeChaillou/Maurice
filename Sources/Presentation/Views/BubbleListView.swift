import SwiftUI

struct BubbleListView: View {
    let entries: [TranscriptLine]
    var volatileText: String = ""
    var autoScroll: Bool = false

    init(entries: [TranscriptLine], volatileText: String = "", autoScroll: Bool = false) {
        self.entries = entries
        self.volatileText = volatileText
        self.autoScroll = autoScroll
    }

    init(entries: [String], volatileText: String = "", autoScroll: Bool = false) {
        self.entries = entries.map { .text($0) }
        self.volatileText = volatileText
        self.autoScroll = autoScroll
    }

    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    switch entry {
                    case .text(let text, let timestamp):
                        BubbleView(text: text, style: .final, timestamp: timestamp)
                            .bubbleScrollTransition()
                    case .separator(let text):
                        if text == "---" {
                            GeometryReader { geo in
                                Divider()
                                    .frame(width: geo.size.width * 0.9)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .frame(height: 1)
                            .padding(.vertical, 8)
                        } else {
                            Text(text)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                        }
                    }
                }
                if !volatileText.isEmpty {
                    BubbleView(text: volatileText, style: .volatile)
                        .bubbleScrollTransition()
                        .id("volatile")
                }

                Color.clear.frame(height: 1).id("bottom")
            }
            .padding()
            .onChange(of: entries.count) {
                if autoScroll { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .onChange(of: volatileText) {
                if autoScroll { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
        }
    }
}
