import SwiftUI
import AppKit
import UserNotifications

public final class WindowCloseHandler: NSObject, NSWindowDelegate {
    public static let shared = WindowCloseHandler()
    public weak var mainWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func register(window: NSWindow) {
        guard !(window is NSPanel),
              window.className != "NSStatusBarWindow",
              !window.className.contains("StatusBar"),
              window.canBecomeMain else { return }
        
        self.mainWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false // Do NOT destroy window; smoothly hide it
    }
    
    public func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        for window in NSApplication.shared.windows {
            if !(window is NSPanel),
               window.className != "NSStatusBarWindow",
               !window.className.contains("StatusBar"),
               window.canBecomeMain {
                register(window: window)
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

public struct WindowAccessorView: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                WindowCloseHandler.shared.register(window: window)
            }
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                WindowCloseHandler.shared.register(window: window)
            }
        }
    }
}

@main
public struct TidyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var diskInfo = DiskInfoService.shared
    @ObservedObject var storage = StorageManager.shared
    
    public init() {
        // Request notifications permission for downloads organizer & disk alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        
        // Start Downloads Watcher if auto-organize is enabled
        if StorageManager.shared.settings.autoOrganizeDownloads {
            DownloadsWatcher.shared.startWatching(path: StorageManager.shared.settings.downloadsWatchedPath)
        }
    }
    
    public var body: some Scene {
        // Main Application Window
        WindowGroup("Tidy", id: "main-window") {
            MainContentView()
                .frame(minWidth: 920, minHeight: 640)
                .preferredColorScheme(.light) // Strictly enforce non-dark, elegant white & blush UI
                .background(WindowAccessorView())
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {}
                    .disabled(true)
            }
        }
        
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarExtraView(
                onOpenMainWindow: {
                    bringMainWindowToFront()
                },
                onOpenSettings: {
                    bringMainWindowToFront()
                },
                onQuickScan: {
                    bringMainWindowToFront()
                }
            )
            .preferredColorScheme(.light)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                if storage.settings.showFreeSpaceInMenuBar {
                    Text(diskInfo.formattedFree)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
    
    private func bringMainWindowToFront() {
        WindowCloseHandler.shared.showMainWindow()
    }
}

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Set standard app activation policy
        NSApplication.shared.setActivationPolicy(.regular)
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notif in
            guard let window = notif.object as? NSWindow else { return }
            WindowCloseHandler.shared.register(window: window)
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowCloseHandler.shared.showMainWindow()
        return true
    }
}
