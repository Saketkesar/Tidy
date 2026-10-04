import Foundation
import AppKit

@MainActor
public class UninstallerViewModel: ObservableObject {
    @Published public var apps: [AppInfo] = []
    @Published public var selectedApp: AppInfo? = nil
    @Published public var isScanning: Bool = false
    @Published public var searchText: String = ""
    @Published public var sortBySize: Bool = true
    
    @Published public var isShowingConfirmSheet: Bool = false
    @Published public var lastCleanResult: CleanResult? = nil
    
    public init() {
        scanInstalledApps()
    }
    
    public var filteredApps: [AppInfo] {
        var list = apps
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.bundleId?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        if sortBySize {
            list.sort { $0.totalSize > $1.totalSize }
        } else {
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }
    
    public func scanInstalledApps() {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        selectedApp = nil
        
        Task.detached(priority: .userInitiated) {
            let found = await Self.discoverApps()
            await MainActor.run {
                self.apps = found
                self.selectedApp = found.first
                self.isScanning = false
            }
        }
    }
    
    public func selectApp(_ app: AppInfo) {
        self.selectedApp = app
        // Re-check running status
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            let running = SafetyManager.shared.isApplicationRunning(bundleId: app.bundleId, name: app.name)
            apps[idx].isRunning = running.isRunning
            self.selectedApp?.isRunning = running.isRunning
        }
    }
    
    public func quitRunningApp() {
        guard let app = selectedApp, let bid = app.bundleId else { return }
        let running = SafetyManager.shared.isApplicationRunning(bundleId: bid, name: app.name)
        if let runner = running.runningApp {
            runner.terminate()
            // Check again after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.selectApp(app)
            }
        }
    }
    
    public func uninstallSelectedApp() async {
        guard let app = selectedApp else { return }
        
        // Build list of items to trash
        var itemsToTrash: [ScanItem] = []
        
        // 1. App Bundle
        itemsToTrash.append(ScanItem(
            url: app.bundleURL,
            name: app.name,
            path: app.bundleURL.path,
            sizeBytes: app.appSize,
            status: .ready,
            category: .orphanedLeftovers,
            isSelected: true,
            bundleId: app.bundleId
        ))
        
        // 2. Selected Leftovers
        for leftover in app.leftovers where leftover.isSelected {
            itemsToTrash.append(ScanItem(
                url: leftover.url,
                name: leftover.name,
                path: leftover.path,
                sizeBytes: leftover.sizeBytes,
                status: .ready,
                category: .orphanedLeftovers,
                isSelected: true,
                bundleId: app.bundleId
            ))
        }
        
        let result = await TrashService.shared.cleanItems(
            itemsToTrash,
            actionType: .uninstaller,
            allowApplicationBundle: true
        )
        self.lastCleanResult = result
        
        // Remove app from list
        self.apps.removeAll { $0.id == app.id }
        self.selectedApp = self.apps.first
    }
    
    private static func discoverApps() async -> [AppInfo] {
        var results: [AppInfo] = []
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        let scanner = FileScanner.shared
        let myBundleId = Bundle.main.bundleIdentifier ?? "com.tidy.mac"
        
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentAccessDateKey], options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for itemURL in contents where itemURL.pathExtension == "app" {
                let name = itemURL.deletingPathExtension().lastPathComponent
                
                // Exclude system Apple apps or apps in /System/Applications
                if itemURL.path.hasPrefix("/System") { continue }
                
                guard let bundle = Bundle(url: itemURL) else { continue }
                let bundleId = bundle.bundleIdentifier
                
                // Skip Apple system apps & Tidy itself
                if bundleId == myBundleId || name.lowercased() == "tidy" { continue }
                if let bid = bundleId, bid.hasPrefix("com.apple.") && itemURL.path.hasPrefix("/Applications/Safari") {
                    // Do not offer to uninstall Safari
                    continue
                }
                
                let accessDate = (try? itemURL.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
                let appSize = scanner.computeSize(of: itemURL)
                let runningCheck = SafetyManager.shared.isApplicationRunning(bundleId: bundleId, name: name)
                
                // Find leftovers
                let leftovers = findLeftovers(bundleId: bundleId, appName: name)
                
                results.append(AppInfo(
                    name: name,
                    bundleId: bundleId,
                    bundleURL: itemURL,
                    appSize: appSize,
                    leftovers: leftovers,
                    lastUsedDate: accessDate,
                    isRunning: runningCheck.isRunning
                ))
            }
        }
        
        results.sort { $0.totalSize > $1.totalSize }
        return results
    }
    
    private static func findLeftovers(bundleId: String?, appName: String) -> [AppLeftoverItem] {
        guard let bundleId = bundleId, !bundleId.isEmpty else { return [] }
        var list: [AppLeftoverItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let scanner = FileScanner.shared
        
        let candidates: [(URL, LeftoverType, String)] = [
            (home.appendingPathComponent("Library/Caches/\(bundleId)"), .cache, "Caches"),
            (home.appendingPathComponent("Library/Preferences/\(bundleId).plist"), .preference, "Preferences"),
            (home.appendingPathComponent("Library/Application Support/\(appName)"), .applicationSupport, "Application Support"),
            (home.appendingPathComponent("Library/Application Support/\(bundleId)"), .applicationSupport, "Application Support"),
            (home.appendingPathComponent("Library/Containers/\(bundleId)"), .container, "Sandboxed Container"),
            (home.appendingPathComponent("Library/Saved Application State/\(bundleId).savedState"), .savedState, "Saved State"),
            (home.appendingPathComponent("Library/Logs/\(appName)"), .logs, "Logs"),
            (home.appendingPathComponent("Library/Logs/\(bundleId)"), .logs, "Logs")
        ]
        
        for (url, type, label) in candidates {
            if fm.fileExists(atPath: url.path) {
                // Ensure not already in list
                if !list.contains(where: { $0.url.path == url.path }) {
                    let size = scanner.computeSize(of: url)
                    list.append(AppLeftoverItem(
                        name: "\(label): \(url.lastPathComponent)",
                        path: url.path,
                        url: url,
                        type: type,
                        sizeBytes: size,
                        isSelected: true
                    ))
                }
            }
        }
        
        return list
    }
}
