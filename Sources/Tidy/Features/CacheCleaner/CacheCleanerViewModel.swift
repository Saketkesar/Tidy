import Foundation
import AppKit

@MainActor
public class CacheCleanerViewModel: ObservableObject {
    @Published public var categories: [ScanCategoryResult] = []
    @Published public var isScanning: Bool = false
    @Published public var selectedCategoryForReview: ScanCategoryResult? = nil
    @Published public var lastCleanResult: CleanResult? = nil
    
    public init() {
        startScan()
    }
    
    public var totalSize: Int64 {
        categories.reduce(0) { $0 + $1.totalSize }
    }
    
    public func startScan() {
        guard !isScanning else { return }
        isScanning = true
        categories = []
        
        Task.detached(priority: .userInitiated) {
            let targetCategories: [ScanCategoryType] = [
                .appCaches,
                .systemLogs,
                .trash,
                .xcodeJunk,
                .packageManagers,
                .iosBackups
            ]
            
            var results: [ScanCategoryResult] = []
            
            for cat in targetCategories {
                if Task.isCancelled { break }
                let items = await FileScanner.shared.scanCategory(cat) { _ in }
                if !items.isEmpty {
                    results.append(ScanCategoryResult(
                        category: cat,
                        items: items,
                        isSelected: cat.isSafeWhitelist
                    ))
                }
            }
            
            let finalResults = results
            await MainActor.run {
                self.categories = finalResults
                self.isScanning = false
            }
        }
    }
    
    public func updateCategory(updatedCategory: ScanCategoryResult) {
        if let idx = categories.firstIndex(where: { $0.category == updatedCategory.category }) {
            categories[idx] = updatedCategory
        }
    }
}
