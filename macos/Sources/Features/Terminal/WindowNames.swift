import AppKit

/// Names for windows (native tab groups), keyed weakly by the group.
///
/// Restored tabs come back one at a time before AppKit regroups them, so each
/// carries its saved name until its group holds more than one tab.
@MainActor
enum WindowNames {
    private static let names = NSMapTable<NSWindowTabGroup, NSString>.weakToStrongObjects()
    private static let restored = NSMapTable<NSWindowController, NSString>.weakToStrongObjects()

    static func name(for window: NSWindow) -> String? {
        guard let group = window.tabGroup else { return nil }
        let controllers = group.windows.compactMap(\.windowController)
        if let name = names.object(forKey: group) {
            controllers.forEach { restored.removeObject(forKey: $0) }
            return name as String
        }

        guard let name = controllers.lazy.compactMap({ restored.object(forKey: $0) }).first else { return nil }
        if group.windows.count > 1 {
            names.setObject(name, forKey: group)
            controllers.forEach { restored.removeObject(forKey: $0) }
        }
        return name as String
    }

    static func setName(_ name: String?, for window: NSWindow) {
        guard let group = window.tabGroup else { return }
        let controllers = group.windows.compactMap(\.windowController)
        controllers.forEach { restored.removeObject(forKey: $0) }
        if let name, !name.isEmpty {
            names.setObject(name as NSString, forKey: group)
        } else {
            names.removeObject(forKey: group)
        }

        for tab in group.windows {
            syncWindowsMenuItem(for: tab)
            tab.invalidateRestorableState()
        }
    }

    static func restore(_ name: String?, for controller: NSWindowController) {
        guard let name, !name.isEmpty else { return }
        restored.setObject(name as NSString, forKey: controller)
    }

    /// Skips closed tabs, which `changeWindowsItem` would add back to the menu.
    static func syncWindowsMenuItem(for window: NSWindow) {
        guard window.windowController is TerminalController,
              window.isVisible || window.tabbedWindows != nil,
              !window.isExcludedFromWindowsMenu else { return }
        NSApp.changeWindowsItem(
            window,
            title: menuTitle(name: name(for: window), tabTitle: window.title),
            filename: false)
    }

    nonisolated static func label(name: String?, selectedTitle: String, tabCount: Int) -> String {
        if let name, !name.isEmpty { return name }
        let title = selectedTitle.isEmpty ? "Untitled" : selectedTitle
        return "\(title) (\(tabCount) \(tabCount == 1 ? "tab" : "tabs"))"
    }

    static func label(for window: NSWindow) -> String {
        let group = window.tabGroup
        return label(
            name: name(for: window),
            selectedTitle: (group?.selectedWindow ?? window).title,
            tabCount: group?.windows.count ?? 1)
    }

    nonisolated static func menuTitle(name: String?, tabTitle: String) -> String {
        guard let name, !name.isEmpty else { return tabTitle }
        return "\(name) — \(tabTitle)"
    }
}
