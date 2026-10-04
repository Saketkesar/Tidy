import Foundation
import AppKit

@MainActor
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public private(set) var hasFullDiskAccess: Bool = false
    @Published public private(set) var lastCheckDate: Date = Date()
    
    private init() {
        checkFullDiskAccess()
        
        // Auto-recheck when user returns to app after toggling in System Settings
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullDiskAccess()
            }
        }
    }
    
    @discardableResult
    public func checkFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safariURL = home.appendingPathComponent("Library/Safari", isDirectory: true)
        
        var granted = false
        
        do {
            // If we have Full Disk Access, listing ~/Library/Safari will succeed.
            // Without Full Disk Access, it fails with Cocoa error 257 (permission denied).
            _ = try FileManager.default.contentsOfDirectory(at: safariURL, includingPropertiesForKeys: nil)
            granted = true
        } catch {
            // Also test ~/Library/Mail as secondary probe
            let mailURL = home.appendingPathComponent("Library/Mail", isDirectory: true)
            if FileManager.default.fileExists(atPath: mailURL.path) {
                do {
                    _ = try FileManager.default.contentsOfDirectory(at: mailURL, includingPropertiesForKeys: nil)
                    granted = true
                } catch {
                    granted = false
                }
            } else {
                granted = false
            }
        }
        
        self.hasFullDiskAccess = granted
        self.lastCheckDate = Date()
        return granted
    }
    
    public func openSystemSettingsFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
