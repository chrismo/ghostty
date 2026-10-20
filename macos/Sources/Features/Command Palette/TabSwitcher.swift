import SwiftUI

struct TabSwitcherEntry {
    let windowName: String?
    let tabTitle: String
    let pwd: String?

    /// Labelled like the Window menu: "window name — tab title".
    var title: String {
        WindowNames.menuTitle(name: windowName, tabTitle: tabTitle.isEmpty ? "Untitled" : tabTitle)
    }

    /// Shells often title tabs with their directory, so it isn't repeated.
    var subtitle: String? {
        guard let pwd, !pwd.isEmpty, !tabTitle.contains(pwd) else { return nil }
        return pwd
    }
}

struct TerminalTabSwitcherView: View {
    let surfaceView: Ghostty.SurfaceView

    @Binding var isPresented: Bool

    @ObservedObject var ghosttyConfig: Ghostty.Config

    var body: some View {
        ZStack {
            if isPresented {
                GeometryReader { geometry in
                    VStack {
                        Spacer().frame(height: geometry.size.height * 0.05)

                        ResponderChainInjector(responder: surfaceView)
                            .frame(width: 0, height: 0)

                        CommandPaletteView(
                            isPresented: $isPresented,
                            backgroundColor: ghosttyConfig.backgroundColor,
                            options: tabOptions,
                            placeholder: "Switch to a tab…",
                            matcher: .fuzzy,
                            selectsTopMatchOnEdit: true,
                            dismissShortcut: ghosttyConfig.keyboardShortcut(for: "toggle_tab_switcher")
                        )
                        .zIndex(1)

                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            guard !newValue else { return }

            // After a choice another window is key, but making the surface
            // first responder marks it focused anyway, so resync focus.
            DispatchQueue.main.async {
                surfaceView.window?.makeFirstResponder(surfaceView)
                BaseTerminalController.controller(owning: surfaceView)?.syncFocusToSurfaceTree()
            }
        }
    }

    private var tabOptions: [CommandOption] {
        Self.tabs().map { window, controller in
            let color = (window as? TerminalWindow)?.tabColor
            let displayColor = color != TerminalTabColor.none ? color : nil
            let entry = TabSwitcherEntry(
                windowName: WindowNames.name(for: window),
                tabTitle: window.title,
                pwd: controller.focusedSurface?.pwd?.abbreviatedPath)

            return CommandOption(
                title: entry.title,
                subtitle: entry.subtitle,
                leadingColor: displayColor?.displayColor.map { Color($0) },
                sortKey: ObjectIdentifier(window)
            ) { [weak controller] in
                guard let controller else { return }
                Self.present(controller)
            }
        }
    }

    /// Every open terminal tab, grouped by window in a stable order, and in
    /// tab bar order within each window.
    static func tabs() -> [(NSWindow, TerminalController)] {
        var seen: Set<ObjectIdentifier> = []
        var groups: [[NSWindow]] = []
        for controller in TerminalController.all {
            guard let window = controller.window else { continue }
            if let group = window.tabGroup {
                guard seen.insert(ObjectIdentifier(group)).inserted else { continue }
                groups.append(group.windows)
            } else {
                groups.append([window])
            }
        }

        // Window numbers don't change as windows come to the front, and new
        // windows usually get higher ones, so this is roughly creation order.
        let byCreation = groups.sorted {
            ($0.map(\.windowNumber).min() ?? 0) < ($1.map(\.windowNumber).min() ?? 0)
        }
        return byCreation.flatMap { group -> [(NSWindow, TerminalController)] in
            group.compactMap { window in
                guard isOpen(window), let controller = window.windowController as? TerminalController else { return nil }
                return (window, controller)
            }
        }
    }

    /// Closed tabs stay alive for undo. Checked again on choosing, since a
    /// tab may close while the switcher is open.
    private static func isOpen(_ window: NSWindow) -> Bool {
        window.isVisible || window.isMiniaturized || window.tabbedWindows != nil
    }

    private static func present(_ controller: TerminalController) {
        guard let window = controller.window, isOpen(window) else { return }
        let target = controller.focusedSurface.flatMap { controller.surfaceTree.contains($0) ? $0 : nil }
            ?? controller.surfaceTree.first { _ in true }
        guard let target else { return }

        NotificationCenter.default.post(
            name: Ghostty.Notification.ghosttyPresentTerminal,
            object: target
        )
    }
}
