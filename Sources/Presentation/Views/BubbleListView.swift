import SwiftUI

struct BubbleListView: View {
    let entries: [String]
    var volatileText: String = ""
    var autoScroll: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    BubbleView(text: entry, style: .final)
                        .bubbleScrollTransition()
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
