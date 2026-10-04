import SwiftUI
import AppKit

public struct MenuBarExtraView: View {
    @ObservedObject var diskInfo = DiskInfoService.shared
    @ObservedObject var downloads = DownloadsOrganizerViewModel()
    public var onOpenMainWindow: () -> Void
    public var onOpenSettings: () -> Void
    public var onQuickScan: () -> Void
    
    public init(
        onOpenMainWindow: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuickScan: @escaping () -> Void
    ) {
        self.onOpenMainWindow = onOpenMainWindow
        self.onOpenSettings = onOpenSettings
        self.onQuickScan = onQuickScan
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                TidyIcon("tidy-icon", size: 24, sfFallback: "sparkles")
                Text("Tidy")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                Spacer()
                Text("\(diskInfo.formattedFree) free")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(TidyTheme.successColor)
            }
            
            // Storage Bar
            VStack(alignment: .leading, spacing: 4) {
                Text("Free: \(diskInfo.formattedFree) of \(diskInfo.formattedTotal)")
                    .font(.system(size: 11))
                    .foregroundColor(TidyTheme.textSecondary)
                StorageProgressBar(usedPercentage: diskInfo.usedPercentage, height: 8)
            }
            
            Divider()
                .opacity(0.5)
            
            // Downloads Loose Files
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloads Folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("\(downloads.looseFilesCount) loose files (\(ByteCountFormatter.string(fromByteCount: downloads.looseFilesSizeBytes, countStyle: .file)))")
                        .font(.system(size: 11))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                Spacer()
            }
            
            // Action Buttons
            VStack(spacing: 8) {
                Button(action: {
                    downloads.buildPreview()
                    onOpenMainWindow()
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Organize Downloads")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TidyTheme.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onQuickScan()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Open Smart Scan")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(TidyTheme.textPrimary)
                    .frame(maxWidth: .infinity)
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
            
            Divider()
                .opacity(0.5)
            
            // Footer Navigation
            HStack {
                Button("Open Tidy") {
                    onOpenMainWindow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(TidyTheme.primaryRose)
                
                Spacer()
                
                Button("Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundColor(TidyTheme.textSecondary)
                
                Text("•")
                    .foregroundColor(TidyTheme.textMuted)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundColor(TidyTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(TidyTheme.cardBackground)
        .onAppear {
            diskInfo.refreshDiskInfo()
            downloads.refreshLooseFiles()
        }
    }
}
