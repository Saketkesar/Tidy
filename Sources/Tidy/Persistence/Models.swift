import Foundation
import AppKit

// MARK: - App Settings
public struct AppSettings: Codable, Equatable {
    public var launchAtLogin: Bool = false
    public var showFreeSpaceInMenuBar: Bool = true
    public var dryRunMode: Bool = false
    public var allowPermanentDelete: Bool = false
    public var userProtectedPaths: [String] = []
    
    // Downloads Organizer
    public var downloadsWatchedPath: String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    public var downloadsDestinationPath: String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/Sorted").path
    public var autoOrganizeDownloads: Bool = false
    public var organizeMinAgeDays: Int = 0
    public var groupByMonth: Bool = false
    
    // Notifications & Updates
    public var notifyOrganizerActivity: Bool = true
    public var notifyLowDiskSpace: Bool = true
    public var lowDiskSpaceThresholdPercent: Int = 10
    public var autoCheckUpdates: Bool = true
    
    // Last Scan Metadata (real runtime values)
    public var lastSmartScanDate: Date? = nil
    public var lastReclaimableBytes: Int64? = nil
    public var lastCleanDate: Date? = nil
    public var lastCleanBytesFreed: Int64? = nil
    
    public init() {}
}

// MARK: - Organizer Rules
public enum RuleMatchType: String, Codable, CaseIterable {
    case extensions = "Extensions"
    case nameContains = "Name Contains"
    case minSizeMB = "Min Size (MB)"
    case olderThanDays = "Older Than (Days)"
    case everythingElse = "Everything Else"
}

public struct OrganizerRule: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var matchType: RuleMatchType
    public var matchValue: String
    public var destinationSubfolder: String
    public var order: Int
    
    public init(id: UUID = UUID(), name: String, isEnabled: Bool = true, matchType: RuleMatchType, matchValue: String, destinationSubfolder: String, order: Int) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.matchType = matchType
        self.matchValue = matchValue
        self.destinationSubfolder = destinationSubfolder
        self.order = order
    }
}

// MARK: - Clean History
public enum HistoryActionType: String, Codable {
    case smartScan = "Smart Scan Clean"
    case cacheClean = "Cache & Junk Clean"
    case largeFilesClean = "Large Files Clean"
    case duplicatesClean = "Duplicates Clean"
    case uninstaller = "App Uninstalled"
    case downloadsOrganized = "Downloads Organized"
}

public struct CleanHistoryEntry: Identifiable, Codable {
    public var id: UUID
    public var timestamp: Date
    public var actionType: HistoryActionType
    public var title: String
    public var bytesFreed: Int64
    public var itemsCount: Int
    public var isUndone: Bool
    public var records: [HistoryItemRecord]
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), actionType: HistoryActionType, title: String, bytesFreed: Int64, itemsCount: Int, isUndone: Bool = false, records: [HistoryItemRecord]) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.title = title
        self.bytesFreed = bytesFreed
        self.itemsCount = itemsCount
        self.isUndone = isUndone
        self.records = records
    }
}

public struct HistoryItemRecord: Identifiable, Codable {
    public var id: UUID
    public var originalPath: String
    public var resultingTrashPath: String?
    public var movedDestinationPath: String?
    public var sizeBytes: Int64
    public var itemName: String
    public var isRestored: Bool
    public var statusDescription: String
    
    public init(id: UUID = UUID(), originalPath: String, resultingTrashPath: String? = nil, movedDestinationPath: String? = nil, sizeBytes: Int64, itemName: String, isRestored: Bool = false, statusDescription: String = "In Trash") {
        self.id = id
        self.originalPath = originalPath
        self.resultingTrashPath = resultingTrashPath
        self.movedDestinationPath = movedDestinationPath
        self.sizeBytes = sizeBytes
        self.itemName = itemName
        self.isRestored = isRestored
        self.statusDescription = statusDescription
    }
}

// MARK: - Scanned Items
public enum ScanItemStatus: Equatable, Hashable {
    case ready
    case appIsOpen(String)
    case noPermission
    case inUse
    case protected
    
    public var displayText: String {
        switch self {
        case .ready: return "Ready"
        case .appIsOpen(let app): return "App is open (\(app)) - quit it to clean"
        case .noPermission: return "No permission"
        case .inUse: return "File in use"
        case .protected: return "Protected system path"
        }
    }
    
    public var isCleanable: Bool {
        if case .ready = self { return true }
        return false
    }
}

public enum ScanCategoryType: String, CaseIterable, Identifiable {
    case appCaches = "App caches"
    case systemLogs = "System logs (user)"
    case trash = "Trash"
    case oldDownloads = "Old downloads (>30d)"
    case xcodeJunk = "Xcode junk"
    case packageManagers = "Package manager caches"
    case iosBackups = "iOS device backups"
    case largeFiles = "Large files (>500MB)"
    case orphanedLeftovers = "Orphaned app leftovers"
    
    public var id: String { rawValue }
    
    public var isSafeWhitelist: Bool {
        switch self {
        case .appCaches, .systemLogs, .trash:
            return true
        default:
            return false
        }
    }
}

public struct ScanItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public var status: ScanItemStatus
    public let category: ScanCategoryType
    public var isSelected: Bool
    public let bundleId: String?
    
    public init(id: UUID = UUID(), url: URL, name: String, path: String, sizeBytes: Int64, status: ScanItemStatus = .ready, category: ScanCategoryType, isSelected: Bool = false, bundleId: String? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.status = status
        self.category = category
        self.isSelected = isSelected
        self.bundleId = bundleId
    }
    
    public static func == (lhs: ScanItem, rhs: ScanItem) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected && lhs.status == rhs.status
    }
}

public struct ScanCategoryResult: Identifiable {
    public var id: ScanCategoryType { category }
    public let category: ScanCategoryType
    public let title: String
    public var items: [ScanItem]
    public var isSelected: Bool
    
    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedSize: Int64 {
        items.filter { $0.isSelected && $0.status.isCleanable }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedCount: Int {
        items.filter { $0.isSelected && $0.status.isCleanable }.count
    }
    
    public init(category: ScanCategoryType, items: [ScanItem], isSelected: Bool? = nil) {
        self.category = category
        self.title = category.rawValue
        self.items = items
        self.isSelected = isSelected ?? category.isSafeWhitelist
    }
}

// MARK: - Duplicates
public struct DuplicateGroup: Identifiable {
    public let id: UUID
    public let hashValue: String
    public let fileSize: Int64
    public var files: [DuplicateFileItem]
    
    public var wastedBytes: Int64 {
        let selectedCount = files.filter { $0.isSelectedForRemoval }.count
        return Int64(selectedCount) * fileSize
    }
    
    public init(id: UUID = UUID(), hashValue: String, fileSize: Int64, files: [DuplicateFileItem]) {
        self.id = id
        self.hashValue = hashValue
        self.fileSize = fileSize
        self.files = files
    }
}

public struct DuplicateFileItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let path: String
    public let fileName: String
    public let modifiedDate: Date
    public var isSelectedForRemoval: Bool
    
    public init(id: UUID = UUID(), url: URL, path: String, fileName: String, modifiedDate: Date, isSelectedForRemoval: Bool = false) {
        self.id = id
        self.url = url
        self.path = path
        self.fileName = fileName
        self.modifiedDate = modifiedDate
        self.isSelectedForRemoval = isSelectedForRemoval
    }
}

// MARK: - App Uninstaller
public enum LeftoverType: String, CaseIterable {
    case cache = "Caches"
    case preference = "Preferences"
    case applicationSupport = "Application Support"
    case container = "Containers"
    case savedState = "Saved Application State"
    case logs = "Logs"
}

public struct AppLeftoverItem: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let path: String
    public let url: URL
    public let type: LeftoverType
    public let sizeBytes: Int64
    public var isSelected: Bool
    
    public init(id: UUID = UUID(), name: String, path: String, url: URL, type: LeftoverType, sizeBytes: Int64, isSelected: Bool = true) {
        self.id = id
        self.name = name
        self.path = path
        self.url = url
        self.type = type
        self.sizeBytes = sizeBytes
        self.isSelected = isSelected
    }
}

public struct AppInfo: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let bundleId: String?
    public let bundleURL: URL
    public let appSize: Int64
    public var leftovers: [AppLeftoverItem]
    public let lastUsedDate: Date?
    public var isRunning: Bool
    
    public var totalLeftoverSize: Int64 {
        leftovers.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var totalSize: Int64 {
        appSize + totalLeftoverSize
    }
    
    public init(id: UUID = UUID(), name: String, bundleId: String?, bundleURL: URL, appSize: Int64, leftovers: [AppLeftoverItem] = [], lastUsedDate: Date?, isRunning: Bool) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.bundleURL = bundleURL
        self.appSize = appSize
        self.leftovers = leftovers
        self.lastUsedDate = lastUsedDate
        self.isRunning = isRunning
    }
}

// MARK: - Startup Items
public enum StartupItemType: String {
    case loginItem = "Login item"
    case userAgent = "User Agent"
    case systemAgent = "System Agent"
}

public struct StartupItemInfo: Identifiable {
    public let id: UUID
    public let name: String
    public let path: String
    public let developer: String
    public let type: StartupItemType
    public var isEnabled: Bool
    public let plistURL: URL?
    
    public init(id: UUID = UUID(), name: String, path: String, developer: String, type: StartupItemType, isEnabled: Bool, plistURL: URL? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.developer = developer
        self.type = type
        self.isEnabled = isEnabled
        self.plistURL = plistURL
    }
}
