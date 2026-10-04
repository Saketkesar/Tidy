import SwiftUI

public enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case smartScan = "Smart Scan"
    case cacheCleaner = "Cache & Junk"
    case largeFiles = "Large & Old Files"
    case duplicates = "Duplicates"
    case downloads = "Downloads"
    case downloadsOrganizer = "Downloads Organizer"
    case uninstaller = "App Uninstaller"
    case startupItems = "Startup Items"
    case history = "History"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "dashboard"
        case .smartScan: return "smart-scan"
        case .cacheCleaner: return "cache-junk"
        case .largeFiles: return "large-files"
        case .duplicates: return "duplicates"
        case .downloads: return "dl-downloads"
        case .downloadsOrganizer: return "downloads"
        case .uninstaller: return "uninstaller"
        case .startupItems: return "startup"
        case .history: return "history"
        case .settings: return "settings"
        }
    }
    
    public var sfFallback: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .smartScan: return "sparkles"
        case .cacheCleaner: return "trash.circle"
        case .largeFiles: return "doc.badge.ellipsis"
        case .duplicates: return "doc.on.doc"
        case .downloads: return "arrow.down.circle.fill"
        case .downloadsOrganizer: return "folder.badge.gearshape"
        case .uninstaller: return "xmark.app"
        case .startupItems: return "bolt.horizontal"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
public class NavigationModel: ObservableObject {
    @Published public var selectedItem: SidebarItem = .dashboard
    @Published public var hasDismissedPermissionOnboarding: Bool = false
    
    public init() {}
    
    public func navigate(to item: SidebarItem) {
        self.selectedItem = item
    }
}
