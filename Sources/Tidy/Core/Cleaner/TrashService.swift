import Foundation
import AppKit

public struct CleanResult: Equatable {
    public let bytesFreed: Int64
    public let itemsMovedCount: Int
    public let itemsSkippedCount: Int
    public let freeSpaceBefore: Int64
    public let freeSpaceAfter: Int64
    public let skippedReasons: [String]
    public let historyEntryId: UUID?
}

@MainActor
public final class TrashService {
    public static let shared = TrashService()
    
    private init() {}
    
    /// Trashes or permanently removes a list of ScanItems with full safety checks and history logging
    public func cleanItems(
        _ items: [ScanItem],
        actionType: HistoryActionType,
        allowUserMediaAndDocs: Bool = false,
        allowApplicationBundle: Bool = false
    ) async -> CleanResult {
        let storage = StorageManager.shared
        let isDryRun = storage.settings.dryRunMode
        let isPermanent = storage.settings.allowPermanentDelete
        
        // Measure initial volume free space
        DiskInfoService.shared.refreshDiskInfo()
        let freeBefore = DiskInfoService.shared.freeBytes
        
        var movedRecords: [HistoryItemRecord] = []
        var totalBytesFreed: Int64 = 0
        var skippedCount = 0
        var skippedReasons: [String] = []
        
        let fm = FileManager.default
        
        for item in items {
            // 1. Safety Blocklist Check
            if SafetyManager.shared.isPathProtected(
                url: item.url,
                allowUserMediaAndDocs: allowUserMediaAndDocs,
                allowApplicationBundle: allowApplicationBundle
            ) {
                skippedCount += 1
                skippedReasons.append("\(item.name): Protected path")
                continue
            }
            
            // 2. Running App Check
            if let bundleId = item.bundleId {
                let running = SafetyManager.shared.isApplicationRunning(bundleId: bundleId)
                if running.isRunning {
                    skippedCount += 1
                    skippedReasons.append("\(item.name): App is running")
                    continue
                }
            }
            
            if isDryRun {
                // Dry run mode - simulate only
                totalBytesFreed += item.sizeBytes
                movedRecords.append(HistoryItemRecord(
                    originalPath: item.path,
                    resultingTrashPath: nil,
                    sizeBytes: item.sizeBytes,
                    itemName: item.name,
                    isRestored: false,
                    statusDescription: "Simulated (Dry Run)"
                ))
                continue
            }
            
            // 3. Perform Move to Trash (Rule S1) or Permanent Removal if already in Trash
            let isInTrash = item.category == .trash || item.url.path.contains("/.Trash/") || item.url.path.hasSuffix("/.Trash")
            var resultingTrashURL: NSURL? = nil
            do {
                if isPermanent || isInTrash {
                    try fm.removeItem(at: item.url)
                    totalBytesFreed += item.sizeBytes
                    movedRecords.append(HistoryItemRecord(
                        originalPath: item.path,
                        resultingTrashPath: nil,
                        sizeBytes: item.sizeBytes,
                        itemName: item.name,
                        isRestored: false,
                        statusDescription: isInTrash ? "Permanently deleted from Trash" : "Deleted permanently"
                    ))
                } else {
                    try fm.trashItem(at: item.url, resultingItemURL: &resultingTrashURL)
                    totalBytesFreed += item.sizeBytes
                    let trashPath = (resultingTrashURL as URL?)?.path
                    movedRecords.append(HistoryItemRecord(
                        originalPath: item.path,
                        resultingTrashPath: trashPath,
                        sizeBytes: item.sizeBytes,
                        itemName: item.name,
                        isRestored: false,
                        statusDescription: "In Trash"
                    ))
                }
            } catch {
                skippedCount += 1
                skippedReasons.append("\(item.name): \(error.localizedDescription)")
            }
        }
        
        // Measure final volume free space
        DiskInfoService.shared.refreshDiskInfo()
        let freeAfter = DiskInfoService.shared.freeBytes
        
        // Create history log entry
        var entryId: UUID? = nil
        if !movedRecords.isEmpty {
            let entry = CleanHistoryEntry(
                actionType: actionType,
                title: isDryRun ? "\(actionType.rawValue) (Dry Run)" : actionType.rawValue,
                bytesFreed: totalBytesFreed,
                itemsCount: movedRecords.count,
                records: movedRecords
            )
            storage.addHistoryEntry(entry)
            entryId = entry.id
        }
        
        return CleanResult(
            bytesFreed: totalBytesFreed,
            itemsMovedCount: movedRecords.count,
            itemsSkippedCount: skippedCount,
            freeSpaceBefore: freeBefore,
            freeSpaceAfter: freeAfter,
            skippedReasons: skippedReasons,
            historyEntryId: entryId
        )
    }
}
