import Foundation
import AppKit

public enum SmartScanState: Equatable {
    case idle
    case scanning(category: String, filesScanned: Int, currentPath: String)
    case review
    case done(result: CleanResult)
}

@MainActor
public class SmartScanViewModel: ObservableObject {
    @Published public var state: SmartScanState = .idle
    @Published public var categoryResults: [ScanCategoryResult] = []
    @Published public var isShowingConfirmSheet: Bool = false
    @Published public var activeReviewCategory: ScanCategoryResult? = nil
    @Published public var showingDetailsModal: Bool = false
    @Published public var isCleaning: Bool = false
    
    private var scanTask: Task<Void, Never>? = nil
    
    public init() {}
    
    public var totalFoundBytes: Int64 {
        categoryResults.reduce(0) { $0 + $1.totalSize }
    }
    
    public var selectedBytes: Int64 {
        categoryResults.filter { $0.isSelected }.reduce(0) { $0 + $1.selectedSize }
    }
    
    public var selectedItemsCount: Int {
        categoryResults.filter { $0.isSelected }.reduce(0) { $0 + $1.selectedCount }
    }
    
    public func startScan() {
        guard state == .idle || ifDoneState() else { return }
        
        categoryResults = []
        state = .scanning(category: "Starting...", filesScanned: 0, currentPath: "")
        
        scanTask = Task.detached(priority: .userInitiated) {
            let categories: [ScanCategoryType] = [
                .appCaches,
                .systemLogs,
                .trash,
                .oldDownloads,
                .xcodeJunk,
                .largeFiles,
                .orphanedLeftovers
            ]
            
            var results: [ScanCategoryResult] = []
            
            for cat in categories {
                if Task.isCancelled { break }
                let items = await FileScanner.shared.scanCategory(cat) { update in
                    Task { @MainActor in
                        self.state = .scanning(
                            category: update.currentCategory,
                            filesScanned: update.filesScanned,
                            currentPath: update.currentPath
                        )
                    }
                }
                
                // Real rule: Only include categories with real results (>0 items)
                if !items.isEmpty {
                    results.append(ScanCategoryResult(
                        category: cat,
                        items: items,
                        isSelected: cat.isSafeWhitelist
                    ))
                }
            }
            
            let finalResults = results
            let totalReclaimable = results.reduce(0) { $0 + $1.totalSize }
            await MainActor.run {
                self.categoryResults = finalResults
                self.state = .review
                
                // Update settings with last scan metadata
                StorageManager.shared.settings.lastSmartScanDate = Date()
                StorageManager.shared.settings.lastReclaimableBytes = totalReclaimable
                StorageManager.shared.saveSettings()
            }
        }
    }
    
    public func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        if !categoryResults.isEmpty {
            state = .review
        } else {
            state = .idle
        }
    }
    
    public func toggleCategorySelection(_ category: ScanCategoryType) {
        if let idx = categoryResults.firstIndex(where: { $0.category == category }) {
            categoryResults[idx].isSelected.toggle()
            let newSelected = categoryResults[idx].isSelected
            for i in categoryResults[idx].items.indices {
                if categoryResults[idx].items[i].status.isCleanable {
                    categoryResults[idx].items[i].isSelected = newSelected
                }
            }
        }
    }
    
    public func updateCategoryItems(category: ScanCategoryType, updatedItems: [ScanItem]) {
        if let idx = categoryResults.firstIndex(where: { $0.category == category }) {
            categoryResults[idx].items = updatedItems
            // If any item selected, category remains active
            categoryResults[idx].isSelected = updatedItems.contains { $0.isSelected }
        }
    }
    
    public func performClean() async {
        isCleaning = true
        var itemsToClean: [ScanItem] = []
        
        for catResult in categoryResults where catResult.isSelected {
            for item in catResult.items where item.isSelected && item.status.isCleanable {
                itemsToClean.append(item)
            }
        }
        
        let result = await TrashService.shared.cleanItems(
            itemsToClean,
            actionType: .smartScan,
            allowUserMediaAndDocs: false
        )
        
        self.isCleaning = false
        self.isShowingConfirmSheet = false
        self.state = .done(result: result)
    }
    
    public func resetToIdle() {
        state = .idle
        categoryResults = []
    }
    
    private func ifDoneState() -> Bool {
        if case .done = state { return true }
        return false
    }
}
