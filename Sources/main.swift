import AppKit
import SwiftUI

// MARK: - Model

struct Browser: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String
    var id: String { bundleID }
    var icon: NSImage {
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 16, height: 16)
        return img
    }
}

final class BrowserStore: ObservableObject {
    static let shared = BrowserStore()
    private let selectedKey = "selectedBrowserBundleID"

    @Published var browsers: [Browser] = []
    @Published var selectedID: String? {
        didSet { UserDefaults.standard.set(selectedID, forKey: selectedKey) }
    }
    @Published var isDefault = false

    private init() {
        selectedID = UserDefaults.standard.string(forKey: selectedKey)
        refresh()
    }

    var selected: Browser? { browsers.first { $0.bundleID == selectedID } }

    func refresh() {
        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        browsers = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)
            .compactMap { url -> Browser? in
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                      id != me, seen.insert(id).inserted else { return nil }
                let name = FileManager.default.displayName(atPath: url.path)
                    .replacingOccurrences(of: ".app", with: "")
                return Browser(url: url, name: name, bundleID: id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if selected == nil {
            // Default to Safari, or whatever comes first.
            selectedID = browsers.first { $0.bundleID == "com.apple.Safari" }?.bundleID ?? browsers.first?.bundleID
        }
        updateIsDefault()
    }

    func updateIsDefault() {
        let current = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
        isDefault = current.flatMap { Bundle(url: $0)?.bundleIdentifier } == Bundle.main.bundleIdentifier
    }

    func setSelfAsDefault() {
        let me = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http") { _ in
            NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https") { _ in
                DispatchQueue.main.async { self.updateIsDefault() }
            }
        }
    }

    func open(_ urls: [URL]) {
        guard let target = selected ?? browsers.first else {
            NSSound.beep()
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: target.url, configuration: config) { _, error in
            if let error { NSLog("browser-swap: failed to open in \(target.name): \(error)") }
        }
    }
}

// MARK: - UI

struct ContentView: View {
    @ObservedObject var store = BrowserStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open links with:").font(.headline)

            Picker("", selection: $store.selectedID) {
                ForEach(store.browsers) { b in
                    Label { Text(b.name) } icon: { Image(nsImage: b.icon) }
                        .tag(Optional(b.bundleID))
                }
            }
            .labelsHidden()
            .frame(minWidth: 260)

            Divider()

            HStack {
                if store.isDefault {
                    Label("Browser Swap is the default browser", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Browser Swap is not the default browser", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Set as Default") { store.setSelfAsDefault() }
                }
            }
            .font(.callout)

            HStack {
                Spacer()
                Button("Refresh List") { store.refresh() }
            }
        }
        .padding(20)
        .frame(width: 380)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.updateIsDefault()
        }
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let store = BrowserStore.shared
    private let skipPromptKey = "skipDefaultBrowserPrompt"

    func applicationDidFinishLaunching(_ note: Notification) {
        setupMainMenu()
        setupStatusItem()

        // Launched just to open a link: forward it and stay in the background.
        let isDefaultLaunch = note.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        guard isDefaultLaunch else { return }

        showWindow()
        if !store.isDefault && !UserDefaults.standard.bool(forKey: skipPromptKey) {
            promptToBecomeDefault()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        store.open(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func promptToBecomeDefault() {
        let alert = NSAlert()
        alert.messageText = "Make Browser Swap your default browser?"
        alert.informativeText = "Browser Swap forwards links to whichever browser you pick in its dropdown, so you can switch browsers instantly."
        alert.addButton(withTitle: "Set as Default")
        alert.addButton(withTitle: "Not Now")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: skipPromptKey)
        }
        if response == .alertFirstButtonReturn {
            store.setSelfAsDefault()
        }
    }

    private func showWindow() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: ContentView()))
            w.title = "Browser Swap"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        store.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // Menu bar icon for quick switching.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.left.arrow.right.circle", accessibilityDescription: "Browser Swap")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        store.refresh()
        for b in store.browsers {
            let mi = NSMenuItem(title: b.name, action: #selector(pickBrowser(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = b.bundleID
            mi.image = b.icon
            mi.state = b.bundleID == store.selectedID ? .on : .off
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        if !store.isDefault {
            let mi = NSMenuItem(title: "Set Browser Swap as Default…", action: #selector(makeDefault), keyEquivalent: "")
            mi.target = self
            menu.addItem(mi)
        }
        let open = NSMenuItem(title: "Open Browser Swap…", action: #selector(openWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func pickBrowser(_ sender: NSMenuItem) { store.selectedID = sender.representedObject as? String }
    @objc private func makeDefault() { store.setSelfAsDefault() }
    @objc private func openWindow() { showWindow() }

    private func setupMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Browser Swap", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Browser Swap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
