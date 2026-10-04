import SwiftUI

public struct CacheCleanerView: View {
    @StateObject private var viewModel = CacheCleanerViewModel()
    
    public init() {}
    
    public var body: some View {
        Group {
            if let reviewCat = viewModel.selectedCategoryForReview {
                ItemReviewView(
                    categoryResult: Binding(
                        get: { reviewCat },
                        set: { updated in
                            self.viewModel.selectedCategoryForReview = updated
                            self.viewModel.updateCategory(updatedCategory: updated)
                        }
                    ),
                    onBack: {
                        self.viewModel.selectedCategoryForReview = nil
                    },
                    onPerformClean: {
                        let cat = reviewCat
                        self.viewModel.selectedCategoryForReview = nil
                        Task {
                            let itemsToClean = cat.items.filter { $0.isSelected && $0.status.isCleanable }
                            _ = await TrashService.shared.cleanItems(itemsToClean, actionType: .cacheClean)
                            viewModel.startScan()
                        }
                    }
                )
            } else {
                mainList
            }
        }
        .background(TidyTheme.windowBackground)
    }
    
    private var mainList: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cache & Junk")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Targeted cleaning of app caches, browser caches, logs, and dev artifacts.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                Spacer()
                Button(action: {
                    viewModel.startScan()
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isScanning {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Scan Caches")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(TidyTheme.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning)
            }
            
            Divider()
                .opacity(0.5)
            
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    AnimatedWebPView("tidy-scanning.webp")
                        .frame(width: 180, height: 180)
                    Text("Inspecting cache and junk locations...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TidyTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.categories.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    AnimatedWebPView("tidy-all-clean.webp")
                        .frame(width: 140, height: 140)
                        .shadow(color: TidyTheme.successColor.opacity(0.18), radius: 14, y: 4)
                    Text("All Caches Clean")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("All scanned cache and log folders are empty or already cleaned.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.categories) { cat in
                            HStack(spacing: 14) {
                                TidyIcon(iconFor(cat: cat.category), size: 32, sfFallback: "folder.fill")
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(cat.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    Text("\(cat.items.count) items found")
                                        .font(.system(size: 12))
                                        .foregroundColor(TidyTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Text(ByteCountFormatter.string(fromByteCount: cat.totalSize, countStyle: .file))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(TidyTheme.textPrimary)
                                
                                Button(action: {
                                    self.viewModel.selectedCategoryForReview = cat
                                }) {
                                    HStack(spacing: 4) {
                                        Text("Review")
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10))
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(TidyTheme.primaryRose)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(TidyTheme.roseLight)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(TidyTheme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                    )
                                    .shadow(color: TidyTheme.cardShadow, radius: 6, y: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding(28)
    }
    
    private func iconFor(cat: ScanCategoryType) -> String {
        switch cat {
        case .appCaches: return "cache-junk"
        case .systemLogs: return "history"
        case .trash: return "cache-junk"
        case .xcodeJunk: return "cat-code"
        case .packageManagers: return "cat-archives"
        case .iosBackups: return "cat-other"
        default: return "cache-junk"
        }
    }
}
