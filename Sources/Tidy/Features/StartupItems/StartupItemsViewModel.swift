import Foundation
import AppKit

@MainActor
public class StartupItemsViewModel: ObservableObject {
    @Published public var items: [StartupItemInfo] = []
    @Published public var isScanning: Bool = false
    
    public init() {
        scanStartupItems()
    }
    
    public func scanStartupItems() {
        isScanning = true
        items = []
        
        Task.detached(priority: .userInitiated) {
            let found = await Self.readStartupItems()
            await MainActor.run {
                self.items = found
                self.isScanning = false
            }
        }
    }
    
    public func toggleItem(_ item: StartupItemInfo) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newState = !item.isEnabled
        
        if let plistURL = item.plistURL {
            // For launch agent plists, we can update the 'Disabled' key
            if var dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
                dict["Disabled"] = !newState
                (dict as NSDictionary).write(to: plistURL, atomically: true)
                items[idx].isEnabled = newState
            }
        } else {
            items[idx].isEnabled = newState
        }
    }
    
    public func openSystemSettingsLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let url2 = URL(string: "x-apple.systempreferences:com.apple.preference.general?LoginItems") {
            NSWorkspace.shared.open(url2)
        }
    }
    
    private static func readStartupItems() async -> [StartupItemInfo] {
        var results: [StartupItemInfo] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        
        // 1. User Launch Agents: ~/Library/LaunchAgents
        let userAgentsURL = home.appendingPathComponent("Library/LaunchAgents")
        if let contents = try? fm.contentsOfDirectory(at: userAgentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for plistURL in contents where plistURL.pathExtension == "plist" {
                if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
                    let label = dict["Label"] as? String ?? plistURL.deletingPathExtension().lastPathComponent
                    let disabled = dict["Disabled"] as? Bool ?? false
                    let dev = parseDeveloper(from: label)
                    
                    results.append(StartupItemInfo(
                        name: label,
                        path: plistURL.path,
                        developer: dev,
                        type: .userAgent,
                        isEnabled: !disabled,
                        plistURL: plistURL
                    ))
                }
            }
        }
        
        // 2. System Launch Agents: /Library/LaunchAgents
        let systemAgentsURL = URL(fileURLWithPath: "/Library/LaunchAgents")
        if let contents = try? fm.contentsOfDirectory(at: systemAgentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for plistURL in contents where plistURL.pathExtension == "plist" {
                if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
                    let label = dict["Label"] as? String ?? plistURL.deletingPathExtension().lastPathComponent
                    let disabled = dict["Disabled"] as? Bool ?? false
                    let dev = parseDeveloper(from: label)
                    
                    results.append(StartupItemInfo(
                        name: label,
                        path: plistURL.path,
                        developer: dev,
                        type: .systemAgent,
                        isEnabled: !disabled,
                        plistURL: plistURL
                    ))
                }
            }
        }
        
        return results
    }
    
    private static func parseDeveloper(from label: String) -> String {
        let parts = label.components(separatedBy: ".")
        if parts.count >= 2 {
            let org = parts[1].capitalized
            return org
        }
        return "Third-Party Developer"
    }
}
