import SwiftUI
import SwiftTerm

struct ConsoleTerminalView: NSViewControllerRepresentable {
    var viewModel: ConsoleViewModel

    func makeNSViewController(context: Context) -> TerminalViewController {
        let vc = TerminalViewController()
        vc.viewModel = viewModel
        vc.delegate = context.coordinator
        return vc
    }

    func updateNSViewController(
        _ nsViewController: TerminalViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let viewModel: ConsoleViewModel

        init(viewModel: ConsoleViewModel) {
            self.viewModel = viewModel
        }

        func sizeChanged(
            source: LocalProcessTerminalView, newCols: Int, newRows: Int
        ) {}

        func setTerminalTitle(
            source: LocalProcessTerminalView, title: String
        ) {}

        func hostCurrentDirectoryUpdate(
            source: TerminalView, directory: String?
        ) {}

        func processTerminated(
            source: TerminalView, exitCode: Int32?
        ) {
            let vm = viewModel
            Task { @MainActor in
                vm.processTerminated()
            }
        }
    }
}

// Map of special key codes to VT escape sequences
let vtSequencesMap: [UInt16: [UInt8]] = [
    126: [0x1B, 0x5B, 0x41],  // Up    → ESC [ A
    125: [0x1B, 0x5B, 0x42],  // Down  → ESC [ B
    124: [0x1B, 0x5B, 0x43],  // Right → ESC [ C
    123: [0x1B, 0x5B, 0x44],  // Left  → ESC [ D
    115: [0x1B, 0x5B, 0x48],  // Home  → ESC [ H
    119: [0x1B, 0x5B, 0x46],  // End   → ESC [ F
    116: [0x1B, 0x5B, 0x35, 0x7E],  // PageUp   → ESC [ 5 ~
    121: [0x1B, 0x5B, 0x36, 0x7E],  // PageDown → ESC [ 6 ~
    117: [0x1B, 0x5B, 0x33, 0x7E]   // Delete   → ESC [ 3 ~
]

final class TerminalViewController: NSViewController {
    var viewModel: ConsoleViewModel?
    weak var delegate: LocalProcessTerminalViewDelegate?
    private var terminalView: LocalProcessTerminalView?
    private var eventMonitor: Any?

    override func loadView() {
        guard let viewModel, let delegate else {
            view = NSView(frame: .zero)
            return
        }
        let tv = viewModel.getOrCreateTerminalView(delegate: delegate)
        terminalView = tv
        view = tv
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        terminalView?.frame = view.bounds
        viewModel?.startSessionIfNeeded()
        view.window?.makeFirstResponder(terminalView)
        installEventMonitor()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let terminalView, terminalView.frame != view.bounds else { return }
        terminalView.frame = view.bounds
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            guard let self,
                  let terminal = self.terminalView,
                  event.window === terminal.window,
                  terminal.window?.firstResponder === terminal,
                  let seq = vtSequencesMap[event.keyCode]
            else {
                return event
            }
            // Send raw VT sequence directly, bypassing Kitty encoding
            terminal.send(seq)
            return nil
        }
    }
}
