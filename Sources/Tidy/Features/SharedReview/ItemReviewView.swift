import SwiftUI
import AppKit

@MainActor
public class ItemReviewModel: ObservableObject {
    @Published public var sortBySize: Bool = true
    @Published public var isShowingConfirmDialog: Bool = false
    public init() {}
}

public struct ItemReviewView: View {
    @Binding public var categoryResult: ScanCategoryResult
    public var onBack: () -> Void
    public var onPerformClean: () -> Void
    
    @StateObject private var model = ItemReviewModel()
    
    public init(
        categoryResult: Binding<ScanCategoryResult>,
        onBack: @escaping () -> Void,
        onPerformClean: @escaping () -> Void
    ) {
        self._categoryResult = categoryResult
        self.onBack = onBack
        self.onPerformClean = onPerformClean
    }
    
    private var sortedItems: [ScanItem] {
        if model.sortBySize {
            return categoryResult.items.sorted { $0.sizeBytes > $1.sizeBytes }
        } else {
            return categoryResult.items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & Filter Bar
            HStack(spacing: 14) {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(TidyTheme.primaryRose)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(TidyTheme.roseLight)
                    )
                }
                .buttonStyle(.plain)
                
                Text(categoryResult.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                
                Spacer()
                
                Picker("Sort", selection: $model.sortBySize) {
                    Text("Size").tag(true)
                    Text("Name").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(TidyTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(TidyTheme.roseSoftBorder),
                alignment: .bottom
            )
            
            // Items List
            if categoryResult.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    AnimatedWebPView("tidy-all-clean.webp")
                        .frame(width: 130, height: 130)
                        .shadow(color: TidyTheme.successColor.opacity(0.18), radius: 14, y: 4)
                    Text("Nothing to clean here")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("All files in this category are already cleaned.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TidyTheme.windowBackground)
            } else {
                List {
                    ForEach(sortedItems) { item in
                        ItemReviewRow(
                            item: item,
                            onToggle: {
                                toggleItemSelection(id: item.id)
                            },
                            onReveal: {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .background(TidyTheme.windowBackground)
            }
            
            // Bottom Action Bar
            HStack(spacing: 16) {
                Button("Select all") {
                    setAllSelection(true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(TidyTheme.primaryRose)
                
                Button("Select none") {
                    setAllSelection(false)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(TidyTheme.textSecondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Selected: \(categoryResult.selectedCount) items, \(ByteCountFormatter.string(fromByteCount: categoryResult.selectedSize, countStyle: .file))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                }
                
                Button(action: {
                    model.isShowingConfirmDialog = true
                }) {
                    Text(categoryResult.category == .trash ? "Empty selected from Trash" : "Move selected to Trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(categoryResult.selectedCount > 0 ? TidyTheme.primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                        )
                }
                .buttonStyle(.plain)
                .disabled(categoryResult.selectedCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(TidyTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(TidyTheme.roseSoftBorder),
                alignment: .top
            )
        }
        .background(TidyTheme.windowBackground)
        .confirmationDialog(
            categoryResult.category == .trash
                ? "Permanently empty \(categoryResult.selectedCount) items (\(ByteCountFormatter.string(fromByteCount: categoryResult.selectedSize, countStyle: .file))) from Trash?"
                : "Move \(categoryResult.selectedCount) items (\(ByteCountFormatter.string(fromByteCount: categoryResult.selectedSize, countStyle: .file))) to Trash?",
            isPresented: $model.isShowingConfirmDialog,
            titleVisibility: .visible
        ) {
            Button(categoryResult.category == .trash ? "Empty Trash" : "Move to Trash", role: .destructive) {
                onPerformClean()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(categoryResult.category == .trash
                ? "These items will be permanently erased from your Mac and cannot be restored."
                : "You can safely undo this action from History at any time.")
        }
    }
    
    private func toggleItemSelection(id: UUID) {
        if let idx = categoryResult.items.firstIndex(where: { $0.id == id }) {
            if categoryResult.items[idx].status.isCleanable {
                categoryResult.items[idx].isSelected.toggle()
            }
        }
    }
    
    private func setAllSelection(_ select: Bool) {
        for idx in categoryResult.items.indices {
            if categoryResult.items[idx].status.isCleanable {
                categoryResult.items[idx].isSelected = select
            }
        }
    }
}

public struct ItemReviewRow: View {
    public let item: ScanItem
    public let onToggle: () -> Void
    public let onReveal: () -> Void
    
    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .disabled(!item.status.isCleanable)
            
            // Icon
            FileIconView(url: item.url)
                .frame(width: 28, height: 28)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Button(action: onReveal) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(TidyTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
                
                Text(item.path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(TidyTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                // Status badge
                HStack(spacing: 4) {
                    Text(item.status.displayText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(statusColor.opacity(0.12)))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(TidyTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                )
        )
    }
    
    private var statusColor: Color {
        switch item.status {
        case .ready: return TidyTheme.successColor
        case .appIsOpen: return TidyTheme.warningColor
        case .noPermission, .protected, .inUse: return TidyTheme.dangerColor
        }
    }
}

public struct FileIconView: View {
    public let url: URL
    
    public var body: some View {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
