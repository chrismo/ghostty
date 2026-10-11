import AppKit

/// The one tab, across all windows, marked as an end of a range of tabs to move.
@MainActor
enum TabMark {
    static let color: TerminalTabColor = .purple

    private(set) static weak var controller: TerminalController?
    private static var savedColor: TerminalTabColor = .none

    nonisolated static func range(mark: Int?, current: Int) -> ClosedRange<Int> {
        guard let mark else { return current...current }
        return min(mark, current)...max(mark, current)
    }

    static func set(_ controller: TerminalController) {
        clear()
        guard let window = controller.window as? TerminalWindow else { return }
        self.controller = controller
        savedColor = window.tabColor
        window.tabColor = color
    }

    static func clear() {
        if let window = controller?.window as? TerminalWindow {
            window.tabColor = savedColor
        }
        controller = nil
        savedColor = .none
    }

    /// Keeps the mark's color out of saved state.
    static func restorableTabColor(of controller: TerminalController) -> TerminalTabColor? {
        if controller === self.controller { return savedColor }
        return (controller.window as? TerminalWindow)?.tabColor
    }
}

extension TerminalController {
    func toggleTabMark() {
        if TabMark.controller === self {
            TabMark.clear()
        } else {
            TabMark.set(self)
        }
    }

    /// Moves to a new window when `target` is nil.
    @discardableResult
    func moveMarkedTabs(to target: NSWindow?) -> Bool {
        guard let window, let tabs = window.tabGroup?.windows,
              let current = tabs.firstIndex(of: window) else { return false }
        let mark = TabMark.controller?.window.flatMap { tabs.firstIndex(of: $0) }
        let moving = Array(tabs[TabMark.range(mark: mark, current: current)])

        guard Self.moveTabs(moving, to: target) else { return false }
        if mark != nil { TabMark.clear() }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    /// `tabs` must be tabs of one window, in order. Moves to a new window
    /// when `target` is nil.
    @discardableResult
    static func moveTabs(_ tabs: [NSWindow], to target: NSWindow?) -> Bool {
        guard let first = tabs.first, let source = first.tabGroup else { return false }
        if let target {
            guard target.tabGroup !== source else { return false }
        } else {
            guard tabs.count < source.windows.count else { return false }
        }

        var anchor: NSWindow
        var rest = tabs[...]
        if let target {
            anchor = target.tabGroup?.windows.last ?? target
        } else {
            first.moveTabToNewWindow(nil)
            anchor = first
            rest = rest.dropFirst()
        }

        for tab in rest {
            tab.tabGroup?.removeWindow(tab)
            guard anchor.addTabbedWindowSafely(tab, ordered: .above) else { break }
            anchor = tab
        }

        for controller in all {
            controller.relabelTabs()
            if let window = controller.window {
                WindowNames.syncWindowsMenuItem(for: window)
            }
        }
        return true
    }

    func promptWindowName() {
        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = "Name Window"
        alert.informativeText = "Names this window and all its tabs. Leave blank to clear the name."
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.stringValue = WindowNames.name(for: window) ?? ""
        alert.accessoryView = textField

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        alert.window.initialFirstResponder = textField

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            WindowNames.setName(textField.stringValue, for: window)
        }
    }
}
