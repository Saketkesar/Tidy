import SwiftUI

@MainActor
public class HistoryViewModel: ObservableObject {
    @Published public var expandedEntryId: UUID? = nil
    @Published public var alertMessage: String? = nil
    @Published public var isShowingAlert: Bool = false
    public init() {}
}

public struct HistoryView: View {
    @ObservedObject var storage = StorageManager.shared
    @StateObject private var viewModel = HistoryViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Cleaning History")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                Text("Log of every cleaning and organizing action with instant restore & undo.")
                    .font(.system(size: 13))
                    .foregroundColor(TidyTheme.textSecondary)
            }
            
            Divider()
                .opacity(0.5)
            
            if storage.history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(TidyTheme.textMuted)
                    Text("No activity yet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Actions performed in Smart Scan, Cache & Junk, or Downloads Organizer will appear here.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(storage.history) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                // Row Header
                                HStack(spacing: 12) {
                                    TidyIcon(iconFor(action: entry.actionType), size: 28, sfFallback: "clock.fill")
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(TidyTheme.textPrimary)
                                        
                                        Text(formatDate(entry.timestamp))
                                            .font(.system(size: 11))
                                            .foregroundColor(TidyTheme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if entry.bytesFreed > 0 {
                                        Text("freed \(ByteCountFormatter.string(fromByteCount: entry.bytesFreed, countStyle: .file))")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(TidyTheme.successColor)
                                    }
                                    
                                    Text("\(entry.itemsCount) items")
                                        .font(.system(size: 12))
                                        .foregroundColor(TidyTheme.textSecondary)
                                    
                                    if !entry.isUndone {
                                        Button(action: {
                                            performUndo(entry: entry)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.uturn.backward")
                                                Text("Undo")
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(TidyTheme.primaryRose)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else {
                                        Text("Restored")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(TidyTheme.primaryRose)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2.5)
                                            .background(Capsule().fill(TidyTheme.roseLight))
                                    }
                                    
                                    Button(action: {
                                        if viewModel.expandedEntryId == entry.id {
                                            viewModel.expandedEntryId = nil
                                        } else {
                                            viewModel.expandedEntryId = entry.id
                                        }
                                    }) {
                                        Image(systemName: viewModel.expandedEntryId == entry.id ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 11))
                                            .foregroundColor(TidyTheme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Expanded Item List
                                if viewModel.expandedEntryId == entry.id {
                                    Divider()
                                        .opacity(0.5)
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(entry.records) { record in
                                            HStack(spacing: 8) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(record.itemName)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(TidyTheme.textPrimary)
                                                    Text(record.originalPath)
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundColor(TidyTheme.textSecondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                                Spacer()
                                                Text(record.statusDescription)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(record.isRestored ? TidyTheme.successColor : TidyTheme.textSecondary)
                                            }
                                            .padding(8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(TidyTheme.innerCardBackground)
                                            )
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(14)
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
        .background(TidyTheme.windowBackground)
        .alert("Undo Result", isPresented: $viewModel.isShowingAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
    
    private func performUndo(entry: CleanHistoryEntry) {
        let result = UndoService.shared.undo(entry: entry)
        if result.failedCount > 0 {
            viewModel.alertMessage = "Restored \(result.restoredCount) items. \(result.failedCount) items could not be restored (Trash was emptied or file was moved)."
        } else {
            viewModel.alertMessage = "Successfully restored \(result.restoredCount) \(result.restoredCount == 1 ? "item" : "items") to original location!"
        }
        viewModel.isShowingAlert = true
    }
    
    private func iconFor(action: HistoryActionType) -> String {
        switch action {
        case .smartScan: return "smart-scan"
        case .cacheClean: return "cache-junk"
        case .largeFilesClean: return "large-files"
        case .duplicatesClean: return "duplicates"
        case .uninstaller: return "uninstaller"
        case .downloadsOrganized: return "downloads"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
