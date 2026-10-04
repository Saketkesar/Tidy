import Foundation
import AppKit

public struct FolderSizeItem: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

@MainActor
public class DiskInfoService: ObservableObject {
    public static let shared = DiskInfoService()
    
    @Published public private(set) var volumeName: String = "Macintosh HD"
    @Published public private(set) var totalBytes: Int64 = 0
    @Published public private(set) var freeBytes: Int64 = 0
    @Published public private(set) var usedBytes: Int64 = 0
    @Published public private(set) var usedPercentage: Double = 0.0
    
    @Published public private(set) var topHomeFolders: [FolderSizeItem] = []
    @Published public private(set) var isCalculatingTopFolders: Bool = false
    @Published public private(set) var topFoldersLastCalculated: Date? = nil
    
    private var calculationTask: Task<Void, Never>? = nil
    
    public init() {
        refreshDiskInfo()
    }
    
    public func refreshDiskInfo() {
        let rootURL = URL(fileURLWithPath: "/")
        do {
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeLocalizedNameKey,
                .volumeNameKey
            ])
            
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
            let used = max(0, total - free)
            
            self.totalBytes = total
            self.freeBytes = free
            self.usedBytes = used
            self.volumeName = values.volumeLocalizedName ?? values.volumeName ?? "Macintosh HD"
            
            if total > 0 {
                self.usedPercentage = min(1.0, max(0.0, Double(used) / Double(total)))
            } else {
                self.usedPercentage = 0.0
            }
        } catch {
            print("Failed to query volume resource values: \(error)")
        }
    }
    
    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
    
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    public func calculateTopHomeFolders(force: Bool = false) {
        if isCalculatingTopFolders && !force { return }
        
        calculationTask?.cancel()
        isCalculatingTopFolders = true
        
        calculationTask = Task.detached(priority: .userInitiated) {
            let home = FileManager.default.homeDirectoryForCurrentUser
            var folderSizes: [FolderSizeItem] = []
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: home,
                    includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                    options: [.skipsPackageDescendants]
                )
                
                for itemURL in contents {
                    if Task.isCancelled { break }
                    
                    let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                    let isDir = values?.isDirectory ?? false
                    let isPackage = values?.isPackage ?? false
                    
                    // We measure directories in home
                    if isDir && !isPackage {
                        let size = await Self.calculateDirectorySize(at: itemURL)
                        if size > 0 {
                            folderSizes.append(FolderSizeItem(
                                name: itemURL.lastPathComponent,
                                path: itemURL.path,
                                sizeBytes: size
                            ))
                        }
                    }
                }
            } catch {
                print("Failed to enumerate home directory: \(error)")
            }
            
            folderSizes.sort { $0.sizeBytes > $1.sizeBytes }
            let top5 = Array(folderSizes.prefix(5))
            
            await MainActor.run {
                self.topHomeFolders = top5
                self.isCalculatingTopFolders = false
                self.topFoldersLastCalculated = Date()
            }
        }
    }
    
    public static func calculateDirectorySize(at url: URL) async -> Int64 {
        var totalSize: Int64 = 0
        let fm = FileManager.default
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            do {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey])
                if values.isRegularFile == true {
                    let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                    totalSize += size
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
}
