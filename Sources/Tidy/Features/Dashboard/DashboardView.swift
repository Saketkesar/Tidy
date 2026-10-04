import SwiftUI

public struct DashboardView: View {
    @ObservedObject var diskInfo = DiskInfoService.shared
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var downloads = DownloadsOrganizerViewModel.shared
    @EnvironmentObject var navigation: NavigationModel
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Low Disk Warning Banner with tidy-low-disk.webp if disk > 80% used
                if diskInfo.usedPercentage > 0.80 {
                    HStack(spacing: 16) {
                        AnimatedWebPView("tidy-low-disk.webp")
                            .frame(width: 80, height: 80)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Disk Space Running Low")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(TidyTheme.textPrimary)
                            Text("You have only \(diskInfo.formattedFree) available. Run Smart Scan to safely reclaim space.")
                                .font(.system(size: 12.5))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            navigation.navigate(to: .smartScan)
                        }) {
                            Text("Free Space Now")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(TidyTheme.primaryGradient)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(TidyTheme.roseChipBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                            )
                    )
                }
                
                // Header & Disk Bar Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diskInfo.volumeName)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(TidyTheme.textPrimary)
                            
                            HStack(spacing: 8) {
                                Text("\(diskInfo.formattedUsed) used of \(diskInfo.formattedTotal)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(TidyTheme.textSecondary)
                                Text("•")
                                    .foregroundColor(TidyTheme.textMuted)
                                Text("\(diskInfo.formattedFree) free")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(TidyTheme.successColor)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            diskInfo.refreshDiskInfo()
                            diskInfo.calculateTopHomeFolders(force: true)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(TidyTheme.textSecondary)
                                .padding(8)
                                .background(Circle().fill(TidyTheme.roseChipBg))
                        }
                        .buttonStyle(.plain)
                        .help("Refresh disk statistics")
                    }
                    
                    StorageProgressBar(usedPercentage: diskInfo.usedPercentage, height: 14)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 10, y: 3)
                )
                
                // Action Cards Row
                HStack(spacing: 16) {
                    // Card 1: Reclaimable now
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TidyIcon("smart-scan", size: 32, sfFallback: "sparkles")
                            Spacer()
                        }
                        
                        Text("Reclaimable Space")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        if let bytes = storage.settings.lastReclaimableBytes {
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(TidyTheme.primaryRose)
                        } else {
                            Text("Ready to scan")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(TidyTheme.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            navigation.navigate(to: .smartScan)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Run Smart Scan")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(TidyTheme.primaryGradient)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(TidyTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                            )
                            .shadow(color: TidyTheme.cardShadow, radius: 10, y: 3)
                    )
                    
                    // Card 2: Downloads folder
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TidyIcon("downloads", size: 32, sfFallback: "folder.badge.gearshape")
                            Spacer()
                        }
                        
                        Text("Downloads Folder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(downloads.looseFilesCount) loose files")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(TidyTheme.textPrimary)
                            Text("\(ByteCountFormatter.string(fromByteCount: downloads.looseFilesSizeBytes, countStyle: .file)) clutter")
                                .font(.system(size: 12))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            navigation.navigate(to: .downloadsOrganizer)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text("Organize Folder")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(TidyTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(TidyTheme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(TidyTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                            )
                            .shadow(color: TidyTheme.cardShadow, radius: 10, y: 3)
                    )
                }
                
                // Last Clean Summary
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(TidyTheme.primaryRose)
                        .font(.system(size: 12))
                    if let date = storage.settings.lastCleanDate, let bytes = storage.settings.lastCleanBytesFreed {
                        Text(formatLastClean(date: date, bytes: bytes))
                            .font(.system(size: 12.5))
                            .foregroundColor(TidyTheme.textSecondary)
                    } else {
                        Text("No clean history yet. Run Smart Scan to free space.")
                            .font(.system(size: 12.5))
                            .foregroundColor(TidyTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Biggest Folders in Home Section (Real Background Scan)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Largest Folders in Home")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(TidyTheme.textPrimary)
                            Text("Live disk usage calculation of your personal folders")
                                .font(.system(size: 12))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        Spacer()
                        if diskInfo.isCalculatingTopFolders {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.65)
                                Text("Calculating...")
                                    .font(.system(size: 11))
                                    .foregroundColor(TidyTheme.textSecondary)
                            }
                        }
                    }
                    
                    if diskInfo.topHomeFolders.isEmpty && !diskInfo.isCalculatingTopFolders {
                        HStack {
                            Text("No folders found or calculation not started")
                                .font(.system(size: 12.5))
                                .foregroundColor(TidyTheme.textSecondary)
                            Spacer()
                            Button("Calculate sizes") {
                                diskInfo.calculateTopHomeFolders(force: true)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(diskInfo.topHomeFolders) { item in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(TidyTheme.primaryRose)
                                        .frame(width: 20)
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    Spacer()
                                    Text(item.formattedSize)
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(TidyTheme.textSecondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(TidyTheme.innerCardBackground)
                                )
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 10, y: 3)
                )
            }
            .padding(28)
        }
        .background(TidyTheme.windowBackground)
        .onAppear {
            diskInfo.refreshDiskInfo()
            if diskInfo.topHomeFolders.isEmpty {
                diskInfo.calculateTopHomeFolders()
            }
        }
    }
    
    private func formatLastClean(date: Date, bytes: Int64) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Last clean: \(formatter.string(from: date)) (freed \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))"
    }
}
