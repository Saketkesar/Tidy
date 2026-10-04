import Foundation
import AppKit
import CryptoKit

@MainActor
public class DuplicatesViewModel: ObservableObject {
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var isScanning: Bool = false
    @Published public var hasCompletedScan: Bool = false
    @Published public var scannedFilesCount: Int = 0
    @Published public var currentPathBeingScanned: String = ""
    @Published public var scanFolderURL: URL
    @Published public var isShowingConfirmSheet: Bool = false
    @Published public var lastCleanResult: CleanResult? = nil
    
    private var scanTask: Task<Void, Never>? = nil
    
    public init() {
        self.scanFolderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }
    
    public var totalWastedBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedBytes }
    }
    
    public var selectedFilesCount: Int {
        duplicateGroups.flatMap { $0.files }.filter { $0.isSelectedForRemoval }.count
    }
    
    public func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        hasCompletedScan = false
        duplicateGroups = []
        scannedFilesCount = 0
        currentPathBeingScanned = "Preparing duplicate scan..."
        
        let targetURL = scanFolderURL
        
        scanTask = Task.detached(priority: .userInitiated) {
            var lastUpdate = CFAbsoluteTimeGetCurrent()
            let groups = await Self.findDuplicates(in: targetURL) { count, path in
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastUpdate >= 0.1 || count % 40 == 0 {
                    lastUpdate = now
                    Task { @MainActor in
                        self.scannedFilesCount = count
                        self.currentPathBeingScanned = path
                    }
                }
            }
            
            await MainActor.run {
                self.duplicateGroups = groups
                self.hasCompletedScan = true
                self.isScanning = false
                self.currentPathBeingScanned = ""
            }
        }
    }
    
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentPathBeingScanned = ""
    }
    
    // Quick Selection Actions
    public func selectKeepOldest() {
        for gIndex in duplicateGroups.indices {
            let sorted = duplicateGroups[gIndex].files.sorted { $0.modifiedDate < $1.modifiedDate }
            guard let oldest = sorted.first else { continue }
            
            for fIndex in duplicateGroups[gIndex].files.indices {
                let file = duplicateGroups[gIndex].files[fIndex]
                duplicateGroups[gIndex].files[fIndex].isSelectedForRemoval = (file.id != oldest.id)
            }
        }
    }
    
    public func selectKeepNewest() {
        for gIndex in duplicateGroups.indices {
            let sorted = duplicateGroups[gIndex].files.sorted { $0.modifiedDate > $1.modifiedDate }
            guard let newest = sorted.first else { continue }
            
            for fIndex in duplicateGroups[gIndex].files.indices {
                let file = duplicateGroups[gIndex].files[fIndex]
                duplicateGroups[gIndex].files[fIndex].isSelectedForRemoval = (file.id != newest.id)
            }
        }
    }
    
    public func deselectAll() {
        for gIndex in duplicateGroups.indices {
            for fIndex in duplicateGroups[gIndex].files.indices {
                duplicateGroups[gIndex].files[fIndex].isSelectedForRemoval = false
            }
        }
    }
    
    public func toggleFileSelection(groupId: UUID, fileId: UUID) {
        guard let gIdx = duplicateGroups.firstIndex(where: { $0.id == groupId }) else { return }
        guard let fIdx = duplicateGroups[gIdx].files.firstIndex(where: { $0.id == fileId }) else { return }
        
        let willBeSelected = !duplicateGroups[gIdx].files[fIdx].isSelectedForRemoval
        if willBeSelected {
            // Check that at least one file remains UNSELECTED in the group
            let currentSelected = duplicateGroups[gIdx].files.filter { $0.isSelectedForRemoval }.count
            if currentSelected + 1 >= duplicateGroups[gIdx].files.count {
                // Cannot select all files in the group - at least one copy must remain!
                return
            }
        }
        
        duplicateGroups[gIdx].files[fIdx].isSelectedForRemoval = willBeSelected
    }
    
    public func deleteSelected() async {
        var itemsToClean: [ScanItem] = []
        for group in duplicateGroups {
            for file in group.files where file.isSelectedForRemoval {
                itemsToClean.append(ScanItem(
                    url: file.url,
                    name: file.fileName,
                    path: file.path,
                    sizeBytes: group.fileSize,
                    status: .ready,
                    category: .largeFiles,
                    isSelected: true
                ))
            }
        }
        
        guard !itemsToClean.isEmpty else { return }
        
        let result = await TrashService.shared.cleanItems(
            itemsToClean,
            actionType: .duplicatesClean,
            allowUserMediaAndDocs: true
        )
        self.lastCleanResult = result
        
        // Remove cleaned files from the duplicate groups
        var updatedGroups: [DuplicateGroup] = []
        for var group in duplicateGroups {
            group.files.removeAll { $0.isSelectedForRemoval }
            if group.files.count >= 2 {
                updatedGroups.append(group)
            }
        }
        self.duplicateGroups = updatedGroups
    }
    
    // MARK: - 4-Step Robust Duplicate Detection Algorithm
    private static func findDuplicates(
        in rootURL: URL,
        onProgress: @escaping (Int, String) -> Void
    ) async -> [DuplicateGroup] {
        var count = 0
        var sizeMap: [Int64: [URL]] = [:]
        
        // Step 1: Enumerate regular files and group by exact byte size
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }
        
        var lastProgressTime = CFAbsoluteTimeGetCurrent()
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { return [] }
            
            // Safety guard: skip system and protected paths
            let isProtected = SafetyManager.shared.isPathProtected(url: fileURL, allowUserMediaAndDocs: true)
            if isProtected {
                continue
            }
            
            let name = fileURL.lastPathComponent
            if name == ".DS_Store" || name == ".localized" || name.starts(with: "._") {
                continue
            }
            
            guard let values = try? fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey
            ]) else { continue }
            
            // Skip symlinks, aliases and non-regular files
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            // Skip 0-byte and tiny files (< 4 KB)
            guard size >= 4096 else { continue }
            
            sizeMap[size, default: []].append(fileURL)
            count += 1
            let now = CFAbsoluteTimeGetCurrent()
            if count % 40 == 0 || now - lastProgressTime > 0.12 {
                lastProgressTime = now
                await Task.yield()
                onProgress(count, fileURL.lastPathComponent)
            }
        }
        
        // Filter groups with 2+ files having identical size
        let candidateSizeGroups = sizeMap.filter { $0.value.count >= 2 }
        if candidateSizeGroups.isEmpty { return [] }
        
        // Step 2: For same-size groups, hash first 64 KB (fast filter)
        var partialHashMap: [String: [URL]] = [:]
        for (size, urls) in candidateSizeGroups {
            for url in urls {
                if Task.isCancelled { return [] }
                await Task.yield()
                onProgress(count, "Comparing: \(url.lastPathComponent)")
                if let partial = hashPrefix(of: url, bytes: 64 * 1024) {
                    let key = "\(size)_\(partial)"
                    partialHashMap[key, default: []].append(url)
                }
            }
        }
        
        let candidatePartialGroups = partialHashMap.filter { $0.value.count >= 2 }
        if candidatePartialGroups.isEmpty { return [] }
        
        // Step 3: Stream full-file SHA-256 for remaining candidates
        var fullHashMap: [String: [URL]] = [:]
        for (_, urls) in candidatePartialGroups {
            for url in urls {
                if Task.isCancelled { return [] }
                await Task.yield()
                onProgress(count, "Verifying content: \(url.lastPathComponent)")
                if let fullHash = await computeFullSHA256(of: url) {
                    fullHashMap[fullHash, default: []].append(url)
                }
            }
        }
        
        // Step 4: Group by full hash (only 2+ matches)
        var finalGroups: [DuplicateGroup] = []
        for (hash, urls) in fullHashMap where urls.count >= 2 {
            var fileItems: [DuplicateFileItem] = []
            var fileSize: Int64 = 0
            
            for url in urls {
                let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .totalFileAllocatedSizeKey,
                    .fileAllocatedSizeKey,
                    .fileSizeKey
                ])
                let modDate = values?.contentModificationDate ?? Date()
                let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
                if fileSize == 0 { fileSize = size }
                
                fileItems.append(DuplicateFileItem(
                    url: url,
                    path: url.path,
                    fileName: url.lastPathComponent,
                    modifiedDate: modDate,
                    isSelectedForRemoval: false
                ))
            }
            
            finalGroups.append(DuplicateGroup(
                hashValue: hash,
                fileSize: fileSize,
                files: fileItems
            ))
        }
        
        finalGroups.sort { $0.fileSize * Int64($0.files.count - 1) > $1.fileSize * Int64($1.files.count - 1) }
        return finalGroups
    }
    
    private static func hashPrefix(of url: URL, bytes: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            guard let data = try handle.read(upToCount: bytes), !data.isEmpty else { return nil }
            return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        } catch {
            return nil
        }
    }
    
    private static func computeFullSHA256(of url: URL) async -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let bufferSize = 64 * 1024
        var bytesProcessed = 0
        
        do {
            while true {
                if Task.isCancelled { return nil }
                guard let data = try handle.read(upToCount: bufferSize), !data.isEmpty else {
                    break
                }
                hasher.update(data: data)
                bytesProcessed += data.count
                if bytesProcessed % (4 * 1024 * 1024) == 0 {
                    await Task.yield()
                }
            }
            return hasher.finalize().map { String(format: "%02hhx", $0) }.joined()
        } catch {
            return nil
        }
    }
}
