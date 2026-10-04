import Foundation
import AppKit

public final class SafetyManager: @unchecked Sendable {
    public static let shared = SafetyManager()
    private let lock = NSLock()
    
    private var customProtectedPaths: [String] = []
    
    public func setCustomProtectedPaths(_ paths: [String]) {
        lock.lock()
        defer { lock.unlock() }
        self.customProtectedPaths = paths
    }
    
    /// Central safety function enforcing Hard Blocklist (Rule S2 & S3)
    public func isPathProtected(url: URL, allowUserMediaAndDocs: Bool = false, allowApplicationBundle: Bool = false) -> Bool {
        // Resolve symlinks to prevent symlink bypass (Rule S3)
        let resolvedURL = url.resolvingSymlinksInPath().standardized
        let resolvedPath = resolvedURL.path
        
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardized.path
        
        // 1. Critical System Blocklist
        let systemBlocklist = [
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/private/var/db",
            "/private/etc",
            "/Library/Apple"
        ]
        
        for prefix in systemBlocklist {
            if resolvedPath == prefix || resolvedPath.hasPrefix(prefix + "/") {
                return true
            }
        }
        
        // 2. /Applications (Protected unless specifically in Uninstaller flow)
        if !allowApplicationBundle {
            if resolvedPath == "/Applications" || resolvedPath.hasPrefix("/Applications/") {
                return true
            }
            let userApps = homePath + "/Applications"
            if resolvedPath == userApps || resolvedPath.hasPrefix(userApps + "/") {
                return true
            }
        }
        
        // 3. User root documents & media (Protected by default unless explicitly in Large Files / Duplicates)
        if !allowUserMediaAndDocs {
            let userMediaAndDocs = [
                homePath + "/Documents",
                homePath + "/Desktop",
                homePath + "/Pictures",
                homePath + "/Movies",
                homePath + "/Music"
            ]
            for userFolder in userMediaAndDocs {
                if resolvedPath == userFolder || resolvedPath.hasPrefix(userFolder + "/") {
                    return true
                }
            }
        }
        
        // 4. Critical User Privacy & Identity (ABSOLUTE BLOCKLIST - NEVER TOUCHED)
        let absoluteUserBlocklist = [
            homePath + "/Library/Keychains",
            homePath + "/Library/Mail",
            homePath + "/Library/Messages",
            homePath + "/Library/Application Support/AddressBook",
            homePath + "/Library/Mobile Documents", // iCloud Drive
            homePath + "/Library/Group Containers"
        ]
        for protectedFolder in absoluteUserBlocklist {
            if resolvedPath == protectedFolder || resolvedPath.hasPrefix(protectedFolder + "/") {
                return true
            }
        }
        
        // 5. Photos libraries & Time Machine
        if resolvedPath.contains(".photoslibrary") ||
            resolvedPath.contains(".timemachine") ||
            resolvedPath.contains("/Backups.backupdb") {
            return true
        }
        
        // 6. User Custom Protected Folders from Settings
        lock.lock()
        let customProtected = self.customProtectedPaths
        lock.unlock()
        for custom in customProtected {
            let customStandard = URL(fileURLWithPath: custom).resolvingSymlinksInPath().standardized.path
            if resolvedPath == customStandard || resolvedPath.hasPrefix(customStandard + "/") {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if an app matching the given bundle ID or name is currently running (Rule S5)
    public func isApplicationRunning(bundleId: String?, name: String? = nil) -> (isRunning: Bool, runningApp: NSRunningApplication?) {
        let runningApps = NSWorkspace.shared.runningApplications
        
        if let bundleId = bundleId, !bundleId.isEmpty {
            if let found = runningApps.first(where: { $0.bundleIdentifier?.lowercased() == bundleId.lowercased() }) {
                return (true, found)
            }
        }
        
        if let name = name, !name.isEmpty {
            let cleanName = name.replacingOccurrences(of: ".app", with: "").lowercased()
            if let found = runningApps.first(where: {
                $0.localizedName?.lowercased() == cleanName ||
                $0.bundleURL?.deletingPathExtension().lastPathComponent.lowercased() == cleanName
            }) {
                return (true, found)
            }
        }
        
        return (false, nil)
    }
    
    /// Detects bundle identifier from a cache folder name (e.g. ~/Library/Caches/com.apple.Safari -> com.apple.Safari)
    public func detectBundleId(from url: URL) -> String? {
        let name = url.lastPathComponent
        if name.contains(".") && name.components(separatedBy: ".").count >= 2 {
            return name
        }
        return nil
    }
}
