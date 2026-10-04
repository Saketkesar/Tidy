import Foundation
import AppKit

public struct ScanProgressUpdate: Equatable {
    public let filesScanned: Int
    public let currentPath: String
    public let currentCategory: String
}

@MainActor
public final class FileScanner {
    public static let shared = FileScanner()
    
    private init() {}
    
    /// Computes real allocated size of a single file or directory
    public func computeSize(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
        let isDir = values?.isDirectory ?? false
        let isPackage = values?.isPackage ?? false
        
        if !isDir || isPackage {
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
        }
        
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }
        
        while let itemURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            let itemValues = try? itemURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey])
            if itemValues?.isRegularFile == true {
                total += Int64(itemValues?.totalFileAllocatedSize ?? itemValues?.fileAllocatedSize ?? itemValues?.fileSize ?? 0)
            }
        }
        
        return total
    }
    
    /// Scans a specific category and returns real items found on the user's Mac
    public func scanCategory(
        _ category: ScanCategoryType,
        onProgress: @escaping (ScanProgressUpdate) -> Void
    ) async -> [ScanItem] {
        var results: [ScanItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        var fileCount = 0
        
        switch category {
        case .appCaches:
            let cachesURL = home.appendingPathComponent("Library/Caches", isDirectory: true)
            results = await scanTopLevelFolders(in: cachesURL, category: .appCaches, checkRunningApps: true, onProgress: { path in
                fileCount += 1
                onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: path, currentCategory: "App caches"))
            })
            
        case .systemLogs:
            let logsURL = home.appendingPathComponent("Library/Logs", isDirectory: true)
            results = await scanTopLevelFolders(in: logsURL, category: .systemLogs, checkRunningApps: false, onProgress: { path in
                fileCount += 1
                onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: path, currentCategory: "System logs (user)"))
            })
            
        case .trash:
            let trashURL = home.appendingPathComponent(".Trash", isDirectory: true)
            results = await scanTopLevelFolders(in: trashURL, category: .trash, checkRunningApps: false, onProgress: { path in
                fileCount += 1
                onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: path, currentCategory: "Trash"))
            })
            
        case .oldDownloads:
            let downloadsURL = home.appendingPathComponent("Downloads", isDirectory: true)
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
            if let contents = try? FileManager.default.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey], options: [.skipsHiddenFiles]) {
                for itemURL in contents {
                    if Task.isCancelled { break }
                    let values = try? itemURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modDate = values?.contentModificationDate, modDate < thirtyDaysAgo {
                        let size = computeSize(of: itemURL)
                        if size > 0 {
                            results.append(ScanItem(
                                url: itemURL,
                                name: itemURL.lastPathComponent,
                                path: itemURL.path,
                                sizeBytes: size,
                                status: .ready,
                                category: .oldDownloads,
                                isSelected: false
                            ))
                        }
                    }
                    fileCount += 1
                    onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: itemURL.path, currentCategory: "Old downloads"))
                }
            }
            
        case .xcodeJunk:
            let devPaths = [
                home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
                home.appendingPathComponent("Library/Developer/Xcode/Archives"),
                home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")
            ]
            for dir in devPaths {
                if FileManager.default.fileExists(atPath: dir.path) {
                    let size = computeSize(of: dir)
                    if size > 0 {
                        results.append(ScanItem(
                            url: dir,
                            name: "Xcode \(dir.lastPathComponent)",
                            path: dir.path,
                            sizeBytes: size,
                            status: .ready,
                            category: .xcodeJunk,
                            isSelected: false
                        ))
                    }
                    fileCount += 1
                    onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: dir.path, currentCategory: "Xcode junk"))
                }
            }
            
        case .packageManagers:
            let pmPaths = [
                home.appendingPathComponent(".npm/_cacache"),
                home.appendingPathComponent("Library/Caches/Homebrew"),
                home.appendingPathComponent("Library/Caches/pip"),
                home.appendingPathComponent(".gradle/caches"),
                home.appendingPathComponent(".cache")
            ]
            for dir in pmPaths {
                if FileManager.default.fileExists(atPath: dir.path) {
                    let size = computeSize(of: dir)
                    if size > 0 {
                        results.append(ScanItem(
                            url: dir,
                            name: "\(dir.lastPathComponent) cache",
                            path: dir.path,
                            sizeBytes: size,
                            status: .ready,
                            category: .packageManagers,
                            isSelected: false
                        ))
                    }
                    fileCount += 1
                    onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: dir.path, currentCategory: "Package manager caches"))
                }
            }
            
        case .iosBackups:
            let backupURL = home.appendingPathComponent("Library/Application Support/MobileSync/Backup", isDirectory: true)
            if FileManager.default.fileExists(atPath: backupURL.path) {
                if let contents = try? FileManager.default.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for backup in contents {
                        let size = computeSize(of: backup)
                        if size > 0 {
                            results.append(ScanItem(
                                url: backup,
                                name: "iOS Backup (\(backup.lastPathComponent.prefix(8))...)",
                                path: backup.path,
                                sizeBytes: size,
                                status: .ready,
                                category: .iosBackups,
                                isSelected: false
                            ))
                        }
                    }
                }
            }
            
        case .largeFiles:
            // Scans ~/Downloads, ~/Desktop, and user root for files > 500 MB
            let targetDirs = [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Movies")
            ]
            for dir in targetDirs {
                if let enumerator = FileManager.default.enumerator(
                    at: dir,
                    includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    while let fileURL = enumerator.nextObject() as? URL {
                        if Task.isCancelled { break }
                        let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey])
                        if values?.isRegularFile == true {
                            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                            if size > 500 * 1024 * 1024 { // > 500 MB
                                results.append(ScanItem(
                                    url: fileURL,
                                    name: fileURL.lastPathComponent,
                                    path: fileURL.path,
                                    sizeBytes: size,
                                    status: .ready,
                                    category: .largeFiles,
                                    isSelected: false
                                ))
                            }
                        }
                        fileCount += 1
                        if fileCount % 15 == 0 {
                            onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: fileURL.path, currentCategory: "Large files"))
                        }
                    }
                }
            }
            
        case .orphanedLeftovers:
            results = await scanOrphanedAppLeftovers(onProgress: { path in
                fileCount += 1
                onProgress(ScanProgressUpdate(filesScanned: fileCount, currentPath: path, currentCategory: "Orphaned app leftovers"))
            })
        }
        
        return results
    }
    
    private func scanTopLevelFolders(
        in directoryURL: URL,
        category: ScanCategoryType,
        checkRunningApps: Bool,
        onProgress: @escaping (String) -> Void
    ) async -> [ScanItem] {
        var items: [ScanItem] = []
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        for itemURL in contents {
            if Task.isCancelled { break }
            onProgress(itemURL.path)
            
            // Check protection
            if SafetyManager.shared.isPathProtected(url: itemURL) {
                continue
            }
            
            var status: ScanItemStatus = .ready
            var bundleId: String? = nil
            
            if checkRunningApps {
                bundleId = SafetyManager.shared.detectBundleId(from: itemURL)
                let runningCheck = SafetyManager.shared.isApplicationRunning(bundleId: bundleId, name: itemURL.lastPathComponent)
                if runningCheck.isRunning {
                    let appName = runningCheck.runningApp?.localizedName ?? itemURL.lastPathComponent
                    status = .appIsOpen(appName)
                }
            }
            
            let size = computeSize(of: itemURL)
            if size > 0 {
                items.append(ScanItem(
                    url: itemURL,
                    name: itemURL.lastPathComponent,
                    path: itemURL.path,
                    sizeBytes: size,
                    status: status,
                    category: category,
                    isSelected: category.isSafeWhitelist && status.isCleanable,
                    bundleId: bundleId
                ))
            }
        }
        
        items.sort { $0.sizeBytes > $1.sizeBytes }
        return items
    }
    
    private func scanOrphanedAppLeftovers(onProgress: @escaping (String) -> Void) async -> [ScanItem] {
        // Collect installed app bundle IDs from /Applications and ~/Applications
        var installedBundleIds: Set<String> = []
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        for dir in appDirs {
            if let apps = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for app in apps where app.pathExtension == "app" {
                    if let bundle = Bundle(url: app), let bid = bundle.bundleIdentifier?.lowercased() {
                        installedBundleIds.insert(bid)
                    }
                }
            }
        }
        
        var leftovers: [ScanItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        
        if let folders = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for folder in folders {
                if Task.isCancelled { break }
                onProgress(folder.path)
                
                let name = folder.lastPathComponent
                if name.contains(".") && name.components(separatedBy: ".").count >= 2 {
                    let bid = name.lowercased()
                    // If bundle ID format and not in installed apps and not Apple
                    if !bid.hasPrefix("com.apple.") && !installedBundleIds.contains(bid) {
                        let size = computeSize(of: folder)
                        if size > 0 {
                            leftovers.append(ScanItem(
                                url: folder,
                                name: name,
                                path: folder.path,
                                sizeBytes: size,
                                status: .ready,
                                category: .orphanedLeftovers,
                                isSelected: false,
                                bundleId: name
                            ))
                        }
                    }
                }
            }
        }
        
        leftovers.sort { $0.sizeBytes > $1.sizeBytes }
        return leftovers
    }
}
