import SwiftUI
import AppKit

public struct DuplicatesView: View {
    @StateObject private var viewModel = DuplicatesViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Duplicate Files")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Byte-exact and SHA-256 duplicate detection. Always keeps at least one copy.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: selectScanFolder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text(viewModel.scanFolderURL.lastPathComponent)
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    
                    if viewModel.isScanning {
                        Button(action: { viewModel.stopScan() }) {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Stop")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.8))
                            )
                        }
                        .buttonStyle(.plain)
                    } else if viewModel.hasCompletedScan {
                        Button(action: { viewModel.startScan() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.primaryGradient)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
                .opacity(0.5)
            
            // Content States
            if viewModel.isScanning {
                // 1. Scanning State
                VStack(spacing: 14) {
                    Spacer()
                    AnimatedWebPView("tidy-scanning.webp")
                        .frame(width: 170, height: 170)
                    Text("Scanning for duplicates (\(viewModel.scannedFilesCount) files checked)...")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text(viewModel.currentPathBeingScanned)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TidyTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 480)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasCompletedScan {
                // 2. Idle / Welcome State (NO LAG, NO PREMATURE SCANNING)
                VStack(spacing: 16) {
                    Spacer()
                    AnimatedWebPView("tidy-duplicates.webp")
                        .frame(width: 170, height: 170)
                    
                    Text("Scan for Duplicate Files")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text("Analyze \(viewModel.scanFolderURL.path) with fast byte size grouping and SHA-256 verification. Safe & deterministic.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                    
                    HStack(spacing: 12) {
                        Button(action: selectScanFolder) {
                            HStack(spacing: 5) {
                                Image(systemName: "folder")
                                Text("Change Folder")
                            }
                            .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { viewModel.startScan() }) {
                            HStack(spacing: 7) {
                                Image(systemName: "magnifyingglass")
                                Text("Start Duplicate Scan")
                            }
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.primaryGradient)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.duplicateGroups.isEmpty {
                // 3. Clean Scan Complete (0 Duplicates)
                VStack(spacing: 14) {
                    Spacer()
                    AnimatedWebPView("tidy-all-clean.webp")
                        .frame(width: 140, height: 140)
                        .shadow(color: TidyTheme.successColor.opacity(0.18), radius: 14, y: 4)
                    Text("No Duplicates Found")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("No identical duplicate files were found in \(viewModel.scanFolderURL.path).")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    
                    Button(action: selectScanFolder) {
                        Text("Scan Another Folder...")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 4. Duplicate Groups Found
                VStack(alignment: .leading, spacing: 12) {
                    // Quick selection helpers
                    HStack(spacing: 10) {
                        Text("Quick select:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        Button("Keep oldest") {
                            viewModel.selectKeepOldest()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Keep newest") {
                            viewModel.selectKeepNewest()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Deselect all") {
                            viewModel.deselectAll()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(TidyTheme.textSecondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.element.id) { index, group in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Group \(index + 1) — \(group.files.count) copies")
                                            .font(.system(size: 13.5, weight: .bold))
                                            .foregroundColor(TidyTheme.textPrimary)
                                        Text("(\(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file)) each)")
                                            .font(.system(size: 11.5, design: .monospaced))
                                            .foregroundColor(TidyTheme.textSecondary)
                                        Spacer()
                                        if group.wastedBytes > 0 {
                                            Text("wasting \(ByteCountFormatter.string(fromByteCount: group.wastedBytes, countStyle: .file))")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(TidyTheme.primaryRose)
                                        }
                                    }
                                    
                                    VStack(spacing: 6) {
                                        ForEach(group.files) { file in
                                            HStack(spacing: 10) {
                                                Toggle("", isOn: Binding(
                                                    get: { file.isSelectedForRemoval },
                                                    set: { _ in viewModel.toggleFileSelection(groupId: group.id, fileId: file.id) }
                                                ))
                                                .toggleStyle(.checkbox)
                                                
                                                FileIconView(url: file.url)
                                                    .frame(width: 24, height: 24)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(file.fileName)
                                                        .font(.system(size: 13, weight: .medium))
                                                        .foregroundColor(TidyTheme.textPrimary)
                                                    Text(file.path)
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundColor(TidyTheme.textSecondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                                
                                                Spacer()
                                                
                                                Text(formatDate(file.modifiedDate))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(TidyTheme.textMuted)
                                                
                                                Button(action: {
                                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                                }) {
                                                    Image(systemName: "magnifyingglass")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(TidyTheme.textSecondary)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(TidyTheme.innerCardBackground)
                                            )
                                        }
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
                    
                    // Bottom Action Bar
                    HStack {
                        Text("Will remove \(viewModel.selectedFilesCount) files, free \(ByteCountFormatter.string(fromByteCount: viewModel.totalWastedBytes, countStyle: .file))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(TidyTheme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.isShowingConfirmSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Move selected to Trash")
                            }
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.selectedFilesCount > 0 ? TidyTheme.primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.selectedFilesCount == 0)
                    }
                }
            }
        }
        .padding(28)
        .background(TidyTheme.windowBackground)
        .confirmationDialog(
            "Move \(viewModel.selectedFilesCount) duplicate copies (\(ByteCountFormatter.string(fromByteCount: viewModel.totalWastedBytes, countStyle: .file))) to Trash?",
            isPresented: $viewModel.isShowingConfirmSheet,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    await viewModel.deleteSelected()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("At least one copy of each file is guaranteed to be kept. You can undo this move from History.")
        }
    }
    
    private func selectScanFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanFolderURL = url
            viewModel.startScan()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
