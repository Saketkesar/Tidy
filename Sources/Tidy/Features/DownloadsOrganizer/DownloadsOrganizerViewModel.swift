import Foundation
import AppKit

public struct OrganizePlanItem: Identifiable, Equatable {
    public var id: String { sourceURL.path }
    public let sourceURL: URL
    public let fileName: String
    public let sizeBytes: Int64
    public let ruleName: String
    public let targetSubfolder: String
    public let targetDirectoryURL: URL
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct SkippedFileItem: Identifiable, Equatable {
    public var id: String { url.path }
    public let url: URL
    public let fileName: String
    public let reason: String
}

public struct OrganizePlan: Equatable {
    public var moves: [OrganizePlanItem]
    public var skipped: [SkippedFileItem]
    public var totalFilesFound: Int
    public var totalBytesToMove: Int64
    
    public init(moves: [OrganizePlanItem] = [], skipped: [SkippedFileItem] = [], totalFilesFound: Int = 0, totalBytesToMove: Int64 = 0) {
        self.moves = moves
        self.skipped = skipped
        self.totalFilesFound = totalFilesFound
        self.totalBytesToMove = totalBytesToMove
    }
}

public struct OrganizeExecutionResult {
    public let movedCount: Int
    public let bytesMoved: Int64
    public let failedCount: Int
    public let historyEntryId: UUID?
}

public final class DownloadsOrganizerPlanner {
    public init() {}
    
    public func createPlan(
        sourceDirectory: URL,
        destinationRoot: URL,
        rules: [OrganizerRule],
        minAgeDays: Int,
        groupByMonth: Bool
    ) -> OrganizePlan {
        let fm = FileManager.default
        var moves: [OrganizePlanItem] = []
        var skipped: [SkippedFileItem] = []
        
        guard let contents = try? fm.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isPackageKey,
                .contentModificationDateKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey
            ],
            options: []
        ) else {
            return OrganizePlan()
        }
        
        let now = Date()
        let minAgeCutoff = minAgeDays > 0 ? now.addingTimeInterval(-Double(minAgeDays) * 86400) : nil
        let inProgressExtensions: Set<String> = ["download", "crdownload", "part", "tmp", "partial"]
        
        let enabledRules = rules.filter { $0.isEnabled }.sorted { $0.order < $1.order }
        
        for fileURL in contents {
            let name = fileURL.lastPathComponent
            
            // 1. Skip hidden files & dotfiles
            if name.hasPrefix(".") {
                skipped.append(SkippedFileItem(url: fileURL, fileName: name, reason: "Hidden file"))
                continue
            }
            
            // 2. Skip destination root folder if inside source
            if fileURL.path == destinationRoot.path || fileURL.standardized.path.hasPrefix(destinationRoot.standardized.path) {
                continue
            }
            
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .contentModificationDateKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
            let isDir = values?.isDirectory ?? false
            let isPackage = values?.isPackage ?? false
            
            // 3. Skip regular directories unless they are bundles/packages or rule explicitly handles
            if isDir && !isPackage {
                skipped.append(SkippedFileItem(url: fileURL, fileName: name, reason: "Folder (already sorted or directory)"))
                continue
            }
            
            // 4. Skip in-progress downloads
            let ext = fileURL.pathExtension.lowercased()
            if inProgressExtensions.contains(ext) {
                skipped.append(SkippedFileItem(url: fileURL, fileName: name, reason: "Still downloading"))
                continue
            }
            
            // 5. Skip files modified in last 10 seconds (actively being written)
            let modDate = values?.contentModificationDate ?? now
            if now.timeIntervalSince(modDate) < 10.0 {
                skipped.append(SkippedFileItem(url: fileURL, fileName: name, reason: "Recently modified (<10s)"))
                continue
            }
            
            // 6. Check age threshold
            if let cutoff = minAgeCutoff, modDate > cutoff {
                skipped.append(SkippedFileItem(url: fileURL, fileName: name, reason: "Newer than \(minAgeDays) days"))
                continue
            }
            
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
            
            // 7. Match against rules (first match wins)
            var matchedRule: OrganizerRule? = nil
            for rule in enabledRules {
                if matchesRule(rule: rule, fileURL: fileURL, fileName: name, ext: ext, sizeBytes: size, modDate: modDate) {
                    matchedRule = rule
                    break
                }
            }
            
            if let rule = matchedRule {
                var targetDir = destinationRoot.appendingPathComponent(rule.destinationSubfolder, isDirectory: true)
                if groupByMonth {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM"
                    let monthFolder = formatter.string(from: modDate)
                    targetDir = targetDir.appendingPathComponent(monthFolder, isDirectory: true)
                }
                
                moves.append(OrganizePlanItem(
                    sourceURL: fileURL,
                    fileName: name,
                    sizeBytes: size,
                    ruleName: rule.name,
                    targetSubfolder: rule.destinationSubfolder,
                    targetDirectoryURL: targetDir
                ))
            } else {
                skipped.append(SkippedFileItem(url: fileURL, fileName: name, reason: "No matching rule"))
            }
        }
        
        let totalBytes = moves.reduce(0) { $0 + $1.sizeBytes }
        return OrganizePlan(
            moves: moves,
            skipped: skipped,
            totalFilesFound: contents.count,
            totalBytesToMove: totalBytes
        )
    }
    
    private func matchesRule(
        rule: OrganizerRule,
        fileURL: URL,
        fileName: String,
        ext: String,
        sizeBytes: Int64,
        modDate: Date
    ) -> Bool {
        switch rule.matchType {
        case .extensions:
            let exts = rule.matchValue.lowercased()
                .components(separatedBy: CharacterSet(charactersIn: ", "))
                .filter { !$0.isEmpty }
            return exts.contains(ext)
            
        case .nameContains:
            let term = rule.matchValue.lowercased()
            return !term.isEmpty && fileName.lowercased().contains(term)
            
        case .minSizeMB:
            if let mb = Double(rule.matchValue) {
                let bytes = Int64(mb * 1024 * 1024)
                return sizeBytes >= bytes
            }
            return false
            
        case .olderThanDays:
            if let days = Double(rule.matchValue) {
                let ageSeconds = Date().timeIntervalSince(modDate)
                return ageSeconds >= (days * 86400)
            }
            return false
            
        case .everythingElse:
            return true
        }
    }
    
    public func executePlan(_ plan: OrganizePlan) -> OrganizeExecutionResult {
        let fm = FileManager.default
        var movedRecords: [HistoryItemRecord] = []
        var totalBytesMoved: Int64 = 0
        var failedCount = 0
        
        for item in plan.moves {
            do {
                // Ensure target directory exists
                try fm.createDirectory(at: item.targetDirectoryURL, withIntermediateDirectories: true)
                
                // Collision handling: never overwrite; append " (2)", " (3)"...
                let targetURL = uniqueDestinationURL(for: item.sourceURL, in: item.targetDirectoryURL)
                
                try fm.moveItem(at: item.sourceURL, to: targetURL)
                totalBytesMoved += item.sizeBytes
                
                movedRecords.append(HistoryItemRecord(
                    originalPath: item.sourceURL.path,
                    resultingTrashPath: nil,
                    movedDestinationPath: targetURL.path,
                    sizeBytes: item.sizeBytes,
                    itemName: item.fileName,
                    isRestored: false,
                    statusDescription: "Moved to \(item.targetSubfolder)"
                ))
            } catch {
                failedCount += 1
                print("Failed to move \(item.fileName): \(error)")
            }
        }
        
        var entryId: UUID? = nil
        if !movedRecords.isEmpty {
            let entry = CleanHistoryEntry(
                actionType: .downloadsOrganized,
                title: "Downloads Organized (\(movedRecords.count) files)",
                bytesFreed: 0,
                itemsCount: movedRecords.count,
                records: movedRecords
            )
            DispatchQueue.main.async {
                StorageManager.shared.addHistoryEntry(entry)
            }
            entryId = entry.id
        }
        
        return OrganizeExecutionResult(
            movedCount: movedRecords.count,
            bytesMoved: totalBytesMoved,
            failedCount: failedCount,
            historyEntryId: entryId
        )
    }
    
    private func uniqueDestinationURL(for sourceURL: URL, in destinationDir: URL) -> URL {
        let fm = FileManager.default
        let fileName = sourceURL.lastPathComponent
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        
        var candidateURL = destinationDir.appendingPathComponent(fileName)
        var counter = 2
        
        while fm.fileExists(atPath: candidateURL.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            candidateURL = destinationDir.appendingPathComponent(newName)
            counter += 1
        }
        
        return candidateURL
    }
}

@MainActor
public class DownloadsOrganizerViewModel: ObservableObject {
    public static let shared = DownloadsOrganizerViewModel()
    
    @Published public var looseFilesCount: Int = 0
    @Published public var looseFilesSizeBytes: Int64 = 0
    @Published public var unsortedCount: Int = 0
    @Published public var isScanning: Bool = false
    
    @Published public var currentPlan: OrganizePlan = OrganizePlan()
    @Published public var isShowingPreviewSheet: Bool = false
    @Published public var isShowingRuleEditor: Bool = false
    @Published public var lastExecutionResult: OrganizeExecutionResult? = nil
    @Published public var isShowingRootPicker: Bool = false
    @Published public var selectedSubfolderForPicker: String? = nil
    
    @Published public var folderIconUpdateTrigger: UUID = UUID()
    @Published public var folderIconStatusMessage: String? = nil
    
    private let planner = DownloadsOrganizerPlanner()
    
    public init() {
        refreshLooseFiles()
    }
    
    public func applyTidyIcon(to folderPath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: folderPath) {
            try? fm.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        }
        
        let possiblePaths = [
            Bundle.main.url(forResource: "tidy-folder-icon", withExtension: "png"),
            Bundle.main.resourceURL?.appendingPathComponent("tidy-folder-icon.png"),
            URL(fileURLWithPath: "/Users/saketkesar/Downloads/dinly/Tidy/Resources/tidy-folder-icon.png"),
            URL(fileURLWithPath: "/Users/saketkesar/Downloads/dinly/Tidy/tidy-folder-icon.png")
        ]
        
        var loadedImage: NSImage? = nil
        for p in possiblePaths.compactMap({ $0 }) {
            if let img = NSImage(contentsOf: p) {
                loadedImage = img
                break
            }
        }
        
        guard let img = loadedImage else {
            folderIconStatusMessage = "Could not load Tidy icon asset"
            return
        }
        
        let success = NSWorkspace.shared.setIcon(img, forFile: folderPath, options: [])
        if success {
            folderIconUpdateTrigger = UUID()
            folderIconStatusMessage = "Applied Tidy folder icon ✨"
        } else {
            folderIconStatusMessage = "Could not update folder icon"
        }
    }
    
    public func applyCustomIcon(from fileURL: URL, to folderPath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: folderPath) {
            try? fm.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        }
        
        guard let img = NSImage(contentsOf: fileURL) else {
            folderIconStatusMessage = "Invalid image file format"
            return
        }
        
        let success = NSWorkspace.shared.setIcon(img, forFile: folderPath, options: [])
        if success {
            folderIconUpdateTrigger = UUID()
            folderIconStatusMessage = "Applied custom folder icon 🎉"
        } else {
            folderIconStatusMessage = "Could not set custom icon"
        }
    }
    
    public func resetToDefaultIcon(for folderPath: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: folderPath) {
            try? fm.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        }
        
        _ = NSWorkspace.shared.setIcon(nil, forFile: folderPath, options: [])
        folderIconUpdateTrigger = UUID()
        folderIconStatusMessage = "Restored macOS default folder icon"
    }
    
    public func subfolderPath(for category: String) -> String {
        let root = StorageManager.shared.settings.downloadsDestinationPath
        return URL(fileURLWithPath: root).appendingPathComponent(category).path
    }
    
    public func applySubfolderIcon(image: NSImage, category: String) {
        let path = subfolderPath(for: category)
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        let success = NSWorkspace.shared.setIcon(image, forFile: path, options: [])
        if success {
            folderIconUpdateTrigger = UUID()
            folderIconStatusMessage = "Applied icon to \(category) ✨"
        }
    }
    
    public func applySubfolderIcon(from fileURL: URL, category: String) {
        guard let img = NSImage(contentsOf: fileURL) else { return }
        applySubfolderIcon(image: img, category: category)
    }
    
    public func resetSubfolderIcon(category: String) {
        let path = subfolderPath(for: category)
        resetToDefaultIcon(for: path)
        folderIconStatusMessage = "Reset icon for \(category)"
    }

    
    public func refreshLooseFiles() {
        isScanning = true
        let storage = StorageManager.shared
        let watchedDir = URL(fileURLWithPath: storage.settings.downloadsWatchedPath)
        let destinationRoot = URL(fileURLWithPath: storage.settings.downloadsDestinationPath)
        let rules = storage.rules
        let minAgeDays = storage.settings.organizeMinAgeDays
        let groupByMonth = storage.settings.groupByMonth
        let localPlanner = self.planner
        
        Task.detached(priority: .userInitiated) {
            let plan = localPlanner.createPlan(
                sourceDirectory: watchedDir,
                destinationRoot: destinationRoot,
                rules: rules,
                minAgeDays: minAgeDays,
                groupByMonth: groupByMonth
            )
            
            await MainActor.run {
                self.currentPlan = plan
                self.looseFilesCount = plan.moves.count + plan.skipped.filter { $0.reason != "Folder (already sorted or directory)" }.count
                self.looseFilesSizeBytes = plan.moves.reduce(0) { $0 + $1.sizeBytes }
                self.unsortedCount = plan.moves.count
                self.isScanning = false
            }
        }
    }
    
    public func buildPreview() {
        let storage = StorageManager.shared
        let watchedDir = URL(fileURLWithPath: storage.settings.downloadsWatchedPath)
        let destinationRoot = URL(fileURLWithPath: storage.settings.downloadsDestinationPath)
        
        self.currentPlan = planner.createPlan(
            sourceDirectory: watchedDir,
            destinationRoot: destinationRoot,
            rules: storage.rules,
            minAgeDays: storage.settings.organizeMinAgeDays,
            groupByMonth: storage.settings.groupByMonth
        )
        self.isShowingPreviewSheet = true
    }
    
    public func executeOrganize() {
        let result = planner.executePlan(currentPlan)
        self.lastExecutionResult = result
        self.isShowingPreviewSheet = false
        refreshLooseFiles()
    }
}
