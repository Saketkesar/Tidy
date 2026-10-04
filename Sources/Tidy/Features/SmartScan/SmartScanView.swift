import SwiftUI

public struct SmartScanView: View {
    @StateObject private var viewModel = SmartScanViewModel()
    
    public init() {}
    
    public var body: some View {
        Group {
            if let reviewCat = viewModel.activeReviewCategory {
                ItemReviewView(
                    categoryResult: Binding(
                        get: { reviewCat },
                        set: { updated in
                            self.viewModel.activeReviewCategory = updated
                            self.viewModel.updateCategoryItems(category: updated.category, updatedItems: updated.items)
                        }
                    ),
                    onBack: {
                        self.viewModel.activeReviewCategory = nil
                    },
                    onPerformClean: {
                        self.viewModel.activeReviewCategory = nil
                        Task {
                            await viewModel.performClean()
                        }
                    }
                )
            } else {
                mainContent
            }
        }
        .background(TidyTheme.windowBackground)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning(let category, let count, let path):
                scanningView(category: category, count: count, path: path)
            case .review:
                resultsReviewView
            case .done(let result):
                doneView(result: result)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
    
    // MARK: - State A: Idle
    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Authentic Cleaning WebP Animation
            AnimatedWebPView("tidy-cleaning-1080.webp")
                .frame(width: 200, height: 200)
                .shadow(color: TidyTheme.primaryRose.opacity(0.12), radius: 24, y: 10)
            
            VStack(spacing: 8) {
                Text("Smart Scan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                
                Text("Checks app caches, system logs, trash, large files, and leftovers.\nAlways protects your running apps and important data.")
                    .font(.system(size: 13.5))
                    .foregroundColor(TidyTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 480)
            }
            
            // Feature Highlights
            HStack(spacing: 12) {
                featureBadge(icon: "shield.checkmark.fill", text: "Safe Whitelist")
                featureBadge(icon: "arrow.uturn.backward.circle.fill", text: "Instant Undo")
                featureBadge(icon: "lock.shield.fill", text: "100% Offline")
            }
            .padding(.top, 4)
            
            // Primary Action Button
            Button(action: {
                viewModel.startScan()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start Smart Scan")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(TidyTheme.primaryGradient)
                        .shadow(color: TidyTheme.primaryRose.opacity(0.35), radius: 10, y: 4)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(TidyTheme.primaryRose)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(TidyTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TidyTheme.roseChipBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - State B: Scanning
    private func scanningView(category: String, count: Int, path: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Authentic Scanning WebP Animation running live
            AnimatedWebPView("tidy-scanning.webp")
                .frame(width: 220, height: 220)
                .shadow(color: TidyTheme.primaryRose.opacity(0.12), radius: 20, y: 8)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning \(category)...")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                }
                
                Text("\(count) items inspected so far")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(TidyTheme.primaryRose)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(TidyTheme.roseLight)
                    )
            }
            
            // Live Path Pill
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Currently inspecting:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(TidyTheme.textMuted)
                    Spacer()
                }
                
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(TidyTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(14)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(TidyTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                    )
                    .shadow(color: TidyTheme.cardShadow, radius: 8, y: 3)
            )
            
            Button(action: {
                viewModel.stopScan()
            }) {
                Text("Cancel Scan")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(TidyTheme.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TidyTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    // MARK: - State C: Review
    private var resultsReviewView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Found \(ByteCountFormatter.string(fromByteCount: viewModel.totalFoundBytes, countStyle: .file))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(TidyTheme.textPrimary)
                        
                        Text("Reclaimable")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(TidyTheme.primaryRose)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(TidyTheme.roseLight))
                    }
                    
                    Text("Review items before moving to Trash. Safe items are pre-selected.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.startScan()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                        Text("Rescan")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(TidyTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TidyTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Category list
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.categoryResults) { cat in
                        HStack(spacing: 14) {
                            Toggle("", isOn: Binding(
                                get: { cat.isSelected },
                                set: { _ in viewModel.toggleCategorySelection(cat.category) }
                            ))
                            .toggleStyle(.checkbox)
                            
                            TidyIcon(iconFor(cat: cat.category), size: 32, sfFallback: "folder.fill")
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(cat.title)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    
                                    if cat.category.isSafeWhitelist {
                                        Text("Safe to Clean")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(TidyTheme.successColor.opacity(0.12)))
                                            .foregroundColor(TidyTheme.successColor)
                                    }
                                }
                                
                                Text("\(cat.items.count) files found")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(TidyTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text(ByteCountFormatter.string(fromByteCount: cat.totalSize, countStyle: .file))
                                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                .foregroundColor(TidyTheme.textPrimary)
                            
                            Button(action: {
                                self.viewModel.activeReviewCategory = cat
                            }) {
                                HStack(spacing: 4) {
                                    Text("Review")
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(TidyTheme.primaryRose)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(TidyTheme.roseLight)
                                )
                            }
                            .buttonStyle(.plain)
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
            
            // Bottom Action Bar Card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected: \(ByteCountFormatter.string(fromByteCount: viewModel.selectedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: viewModel.totalFoundBytes, countStyle: .file))")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text("\(viewModel.selectedItemsCount) items ready to clean")
                        .font(.system(size: 11.5))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.isShowingConfirmSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Clean Selected")
                    }
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.selectedBytes > 0 ? TidyTheme.primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                            .shadow(color: viewModel.selectedBytes > 0 ? TidyTheme.primaryRose.opacity(0.3) : Color.clear, radius: 8, y: 3)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedBytes == 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(TidyTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                    )
                    .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
            )
        }
        .confirmationDialog(
            "Clean \(viewModel.selectedItemsCount) items (\(ByteCountFormatter.string(fromByteCount: viewModel.selectedBytes, countStyle: .file)))?",
            isPresented: $viewModel.isShowingConfirmSheet,
            titleVisibility: .visible
        ) {
            Button("Clean Now", role: .destructive) {
                Task {
                    await viewModel.performClean()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected junk and caches will be cleaned to free space. You can easily undo actions from History.")
        }
    }
    
    // MARK: - State D: Done
    private func doneView(result: CleanResult) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Authentic All Clean Mascot WebP
            AnimatedWebPView("tidy-all-clean.webp")
                .frame(width: 150, height: 150)
                .shadow(color: TidyTheme.successColor.opacity(0.18), radius: 18, y: 6)
            
            VStack(spacing: 6) {
                Text("Clean Complete!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                
                Text("Freed \(ByteCountFormatter.string(fromByteCount: result.bytesFreed, countStyle: .file)) of disk space")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(TidyTheme.primaryRose)
                
                let before = ByteCountFormatter.string(fromByteCount: result.freeSpaceBefore, countStyle: .file)
                let after = ByteCountFormatter.string(fromByteCount: result.freeSpaceAfter, countStyle: .file)
                Text("Available space: \(before) → \(after)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(TidyTheme.textSecondary)
                    .padding(.top, 2)
                
                if result.itemsSkippedCount > 0 {
                    Text("\(result.itemsSkippedCount) items skipped (app running or system protected)")
                        .font(.system(size: 11.5))
                        .foregroundColor(TidyTheme.warningColor)
                        .padding(.top, 4)
                }
            }
            
            HStack(spacing: 12) {
                if let entryId = result.historyEntryId {
                    Button(action: {
                        if let entry = StorageManager.shared.history.first(where: { $0.id == entryId }) {
                            _ = UndoService.shared.undo(entry: entry)
                            viewModel.resetToIdle()
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo Clean")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TidyTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(TidyTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    viewModel.showingDetailsModal = true
                }) {
                    Text("View Log")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TidyTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(TidyTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    viewModel.resetToIdle()
                }) {
                    Text("Done")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(TidyTheme.primaryGradient)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .sheet(isPresented: $viewModel.showingDetailsModal) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Clean Summary Details")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Spacer()
                    Button("Close") { viewModel.showingDetailsModal = false }
                        .buttonStyle(.bordered)
                }
                
                if result.skippedReasons.isEmpty {
                    Text("All selected items were cleanly moved to Trash.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                } else {
                    Text("Skipped Items:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                    List(result.skippedReasons, id: \.self) { reason in
                        Text(reason)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(TidyTheme.textSecondary)
                    }
                }
            }
            .padding(24)
            .frame(width: 480, height: 320)
            .background(TidyTheme.windowBackground)
        }
    }
    
    private func iconFor(cat: ScanCategoryType) -> String {
        switch cat {
        case .appCaches: return "cache-junk"
        case .systemLogs: return "history"
        case .trash: return "cache-junk"
        case .oldDownloads: return "downloads"
        case .xcodeJunk: return "cat-code"
        case .packageManagers: return "cat-archives"
        case .iosBackups: return "cat-other"
        case .largeFiles: return "large-files"
        case .orphanedLeftovers: return "uninstaller"
        }
    }
}
