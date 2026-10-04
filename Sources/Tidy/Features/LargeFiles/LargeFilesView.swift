import SwiftUI
import AppKit

public struct LargeFilesView: View {
    @StateObject private var viewModel = LargeFilesViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Large & Old Files")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                Text("Find large space-hogging files that haven't been opened in a while.")
                    .font(.system(size: 13))
                    .foregroundColor(TidyTheme.textSecondary)
            }
            
            // Filter Bar Card
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("Min size:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TidyTheme.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                    Picker("", selection: $viewModel.minSizeFilter) {
                        ForEach(LargeFileSizeFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .frame(width: 110)
                }
                
                HStack(spacing: 6) {
                    Text("Not opened in:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TidyTheme.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                    Picker("", selection: $viewModel.ageFilter) {
                        ForEach(LargeFileAgeFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .frame(width: 120)
                }
                
                Toggle("Home", isOn: $viewModel.scanHome)
                    .toggleStyle(.checkbox)
                    .fixedSize(horizontal: true, vertical: false)
                
                Button(action: selectCustomFolder) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(viewModel.customFolderPath != nil ? "Folder set" : "Choose folder...")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                Button(action: {
                    if viewModel.isScanning {
                        viewModel.stopScan()
                    } else {
                        viewModel.startScan()
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isScanning {
                            AnimatedWebPView("tidy-microloader.webp")
                                .frame(width: 16, height: 16)
                            Text("Stop")
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Scan Files")
                        }
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
                .fixedSize(horizontal: true, vertical: false)
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
            
            Divider()
                .opacity(0.5)
            
            // Results List
            if viewModel.isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    AnimatedWebPView("tidy-large-files.webp")
                        .frame(width: 170, height: 170)
                    Text("Scanning files (\(viewModel.scannedCount) checked)...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text(viewModel.currentPathBeingScanned)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TidyTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 500)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.files.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    AnimatedWebPView("tidy-all-clean.webp")
                        .frame(width: 140, height: 140)
                        .shadow(color: TidyTheme.successColor.opacity(0.18), radius: 14, y: 4)
                    Text("No large or old files found")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Try changing the minimum size or age filters and click Scan Files.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.files.indices, id: \.self) { index in
                        let item = viewModel.files[index]
                        HStack(spacing: 12) {
                            Toggle("", isOn: $viewModel.files[index].isSelected)
                                .toggleStyle(.checkbox)
                            
                            FileIconView(url: item.url)
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    Text("(\(item.kindDescription))")
                                        .font(.system(size: 11))
                                        .foregroundColor(TidyTheme.textSecondary)
                                    Spacer()
                                    Text(item.formattedSize)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    
                                    Button(action: {
                                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                    }) {
                                        Text("Reveal")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(TidyTheme.textSecondary)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                HStack {
                                    Text(item.path)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(TidyTheme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(item.formattedDate)
                                        .font(.system(size: 11))
                                        .foregroundColor(TidyTheme.textMuted)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(TidyTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                .listStyle(.plain)
            }
            
            // Bottom Action Bar
            HStack {
                Button(action: {
                    viewModel.toggleSelectAll()
                }) {
                    Text("Select all / none")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(TidyTheme.primaryRose)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.files.isEmpty)
                
                Spacer()
                
                Text("Selected: \(viewModel.selectedFilesCount) files, \(ByteCountFormatter.string(fromByteCount: viewModel.selectedFilesSize, countStyle: .file))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(TidyTheme.textPrimary)
                
                Button(action: {
                    viewModel.isShowingConfirmSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Move selected to Trash")
                    }
                    .font(.system(size: 13, weight: .bold))
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
            .padding(.top, 4)
        }
        .padding(28)
        .background(TidyTheme.windowBackground)
        .confirmationDialog(
            "Move \(viewModel.selectedFilesCount) files (\(ByteCountFormatter.string(fromByteCount: viewModel.selectedFilesSize, countStyle: .file))) to Trash?",
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
            Text("These items will be moved to macOS Trash. You can undo this action from History.")
        }
        .onAppear {
            if viewModel.files.isEmpty && !viewModel.isScanning {
                viewModel.startScan()
            }
        }
    }
    
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.customFolderPath = url.path
        }
    }
}
