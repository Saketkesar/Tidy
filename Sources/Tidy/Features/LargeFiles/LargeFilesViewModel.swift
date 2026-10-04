import Foundation
import AppKit

public struct LargeFileItem: Identifiable, Equatable {
    public var id: String { path }
    public let url: URL
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public let lastOpenedDate: Date?
    public let isDateModifiedFallback: Bool
    public let kindDescription: String
    public var isSelected: Bool
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public var formattedDate: String {
        guard let d = lastOpenedDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: d)
        return isDateModifiedFallback ? "modified \(dateStr)" : "last opened \(dateStr)"
    }
}

public enum LargeFileSizeFilter: Int64, CaseIterable, Identifiable {
    case mb50 = 52428800
    case mb100 = 104857600
    case mb250 = 262144000
    case mb500 = 524288000
    case gb1 = 1073741824
    
    public var id: Int64 { rawValue }
    public var label: String {
        switch self {
        case .mb50: return "50 MB"
        case .mb100: return "100 MB"
        case .mb250: return "250 MB"
        case .mb500: return "500 MB"
        case .gb1: return "1 GB"
        }
    }
}

public enum LargeFileAgeFilter: Int, CaseIterable, Identifiable {
    case any = 0
    case days30 = 30
    case days60 = 60
    case days90 = 90
    case days180 = 180
    case year1 = 365
    
    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .any: return "All files"
        case .days30: return "30 days"
        case .days60: return "60 days"
        case .days90: return "90 days"
        case .days180: return "180 days"
        case .year1: return "1 year"
        }
    }
}

@MainActor
public class LargeFilesViewModel: ObservableObject {
    @Published public var files: [LargeFileItem] = []
    @Published public var isScanning: Bool = false
    @Published public var scannedCount: Int = 0
    @Published public var currentPathBeingScanned: String = ""
    
    @Published public var minSizeFilter: LargeFileSizeFilter = .mb50
    @Published public var ageFilter: LargeFileAgeFilter = .any
    @Published public var scanHome: Bool = true
    @Published public var customFolderPath: String? = nil
    
    @Published public var isShowingConfirmSheet: Bool = false
    @Published public var lastCleanResult: CleanResult? = nil
    
    private var scanTask: Task<Void, Never>? = nil
    
    public init() {}
    
    public var selectedFilesCount: Int {
        files.filter { $0.isSelected }.count
    }
    
    public var selectedFilesSize: Int64 {
        files.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public func startScan() {
        guard !isScanning else { return }
        isScanning = true
        files = []
        scannedCount = 0
        currentPathBeingScanned = ""
        
        var targets: [URL] = []
        if scanHome {
            let home = FileManager.default.homeDirectoryForCurrentUser
            targets.append(home.appendingPathComponent("Downloads"))
            targets.append(home.appendingPathComponent("Desktop"))
            targets.append(home.appendingPathComponent("Documents"))
            targets.append(home.appendingPathComponent("Movies"))
            targets.append(home.appendingPathComponent("Music"))
            targets.append(home.appendingPathComponent("Pictures"))
            targets.append(home) // Also scan home root
        }
        if let custom = customFolderPath {
            targets.append(URL(fileURLWithPath: custom))
        }
        
        let minBytes = minSizeFilter.rawValue
        let ageDays = ageFilter.rawValue
        
        scanTask = Task.detached(priority: .userInitiated) {
            var foundItems: [LargeFileItem] = []
            var count = 0
            var lastProgressTime = CFAbsoluteTimeGetCurrent()
            let cutoffDate = ageDays > 0 ? Date().addingTimeInterval(-Double(ageDays) * 86400) : nil
            
            for targetURL in targets {
                if Task.isCancelled { break }
                guard let enumerator = FileManager.default.enumerator(
                    at: targetURL,
                    includingPropertiesForKeys: [
                        .isRegularFileKey,
                        .totalFileAllocatedSizeKey,
                        .fileAllocatedSizeKey,
                        .fileSizeKey,
                        .contentAccessDateKey,
                        .contentModificationDateKey,
                        .localizedTypeDescriptionKey
                    ],
                    options: targetURL.path == FileManager.default.homeDirectoryForCurrentUser.path ? [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) else {
                    continue
                }
                
                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled { break }
                    count += 1
                    let now = CFAbsoluteTimeGetCurrent()
                    if count % 35 == 0 || now - lastProgressTime > 0.12 {
                        lastProgressTime = now
                        let currentCount = count
                        let path = fileURL.path
                        Task { @MainActor in
                            self.scannedCount = currentCount
                            self.currentPathBeingScanned = path
                        }
                    }
                    
                    let values = try? fileURL.resourceValues(forKeys: [
                        .isRegularFileKey,
                        .totalFileAllocatedSizeKey,
                        .fileAllocatedSizeKey,
                        .fileSizeKey,
                        .contentAccessDateKey,
                        .contentModificationDateKey,
                        .localizedTypeDescriptionKey
                    ])
                    guard values?.isRegularFile == true else { continue }
                    
                    let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
                    guard size >= minBytes else { continue }
                    
                    let accessDate = values?.contentAccessDate
                    let modDate = values?.contentModificationDate
                    let effectiveDate = accessDate ?? modDate
                    let isFallback = (accessDate == nil && modDate != nil)
                    
                    if let cutoff = cutoffDate, let checkDate = effectiveDate, checkDate > cutoff {
                        // Opened more recently than the cutoff
                        continue
                    }
                    
                    foundItems.append(LargeFileItem(
                        url: fileURL,
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        sizeBytes: size,
                        lastOpenedDate: effectiveDate,
                        isDateModifiedFallback: isFallback,
                        kindDescription: values?.localizedTypeDescription ?? fileURL.pathExtension.uppercased(),
                        isSelected: false // Hard rule: default NOTHING selected
                    ))
                }
            }
            
            foundItems.sort { $0.sizeBytes > $1.sizeBytes }
            let finalFoundItems = foundItems
            
            await MainActor.run {
                self.files = finalFoundItems
                self.isScanning = false
            }
        }
    }
    
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    public func toggleSelectAll() {
        let allSelected = files.allSatisfy { $0.isSelected }
        for idx in files.indices {
            files[idx].isSelected = !allSelected
        }
    }
    
    public func deleteSelected() async {
        let selected = files.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        
        let scanItems = selected.map {
            ScanItem(
                url: $0.url,
                name: $0.name,
                path: $0.path,
                sizeBytes: $0.sizeBytes,
                status: .ready,
                category: .largeFiles,
                isSelected: true
            )
        }
        
        let result = await TrashService.shared.cleanItems(
            scanItems,
            actionType: .largeFilesClean,
            allowUserMediaAndDocs: true
        )
        self.lastCleanResult = result
        
        // Remove cleaned from list
        self.files.removeAll { $0.isSelected }
    }
}
