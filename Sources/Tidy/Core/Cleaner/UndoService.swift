import Foundation

public struct UndoResult {
    public let restoredCount: Int
    public let failedCount: Int
    public let messages: [String]
}

@MainActor
public final class UndoService {
    public static let shared = UndoService()
    
    private init() {}
    
    public func undo(entry: CleanHistoryEntry) -> UndoResult {
        var restoredCount = 0
        var failedCount = 0
        var messages: [String] = []
        
        let fm = FileManager.default
        
        for record in entry.records {
            if record.isRestored {
                continue
            }
            
            // 1. Undo Downloads Organizer Move
            if let movedPath = record.movedDestinationPath {
                let movedURL = URL(fileURLWithPath: movedPath)
                let originalURL = URL(fileURLWithPath: record.originalPath)
                
                if fm.fileExists(atPath: movedPath) {
                    do {
                        // Ensure parent directory exists
                        try fm.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        
                        var targetURL = originalURL
                        if fm.fileExists(atPath: targetURL.path) {
                            let ext = originalURL.pathExtension
                            let base = originalURL.deletingPathExtension().lastPathComponent
                            let newName = ext.isEmpty ? "\(base) (restored)" : "\(base) (restored).\(ext)"
                            targetURL = originalURL.deletingLastPathComponent().appendingPathComponent(newName)
                        }
                        
                        try fm.moveItem(at: movedURL, to: targetURL)
                        restoredCount += 1
                        messages.append("Restored \(record.itemName) to \(targetURL.path)")
                    } catch {
                        failedCount += 1
                        messages.append("Failed to restore \(record.itemName): \(error.localizedDescription)")
                    }
                } else {
                    failedCount += 1
                    messages.append("File not found at \(movedPath)")
                }
                continue
            }
            
            // 2. Undo Trash Item
            if let trashPath = record.resultingTrashPath {
                let trashURL = URL(fileURLWithPath: trashPath)
                let originalURL = URL(fileURLWithPath: record.originalPath)
                
                if fm.fileExists(atPath: trashPath) {
                    do {
                        try fm.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        
                        var targetURL = originalURL
                        if fm.fileExists(atPath: targetURL.path) {
                            let ext = originalURL.pathExtension
                            let base = originalURL.deletingPathExtension().lastPathComponent
                            let newName = ext.isEmpty ? "\(base) (restored)" : "\(base) (restored).\(ext)"
                            targetURL = originalURL.deletingLastPathComponent().appendingPathComponent(newName)
                        }
                        
                        try fm.moveItem(at: trashURL, to: targetURL)
                        restoredCount += 1
                        messages.append("Restored \(record.itemName)")
                    } catch {
                        failedCount += 1
                        messages.append("Failed to restore \(record.itemName): \(error.localizedDescription)")
                    }
                } else {
                    failedCount += 1
                    messages.append("\(record.itemName): Not recoverable - Trash was emptied")
                }
            } else {
                failedCount += 1
                messages.append("\(record.itemName): Cannot be restored (permanently deleted or dry run)")
            }
        }
        
        StorageManager.shared.markHistoryEntryUndone(id: entry.id)
        return UndoResult(restoredCount: restoredCount, failedCount: failedCount, messages: messages)
    }
}
