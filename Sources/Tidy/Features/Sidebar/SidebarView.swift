import SwiftUI

public struct SidebarView: View {
    @ObservedObject var navigation: NavigationModel
    @ObservedObject var permissions = PermissionManager.shared
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var diskInfo = DiskInfoService.shared
    @ObservedObject var downloadEngine = DownloadEngine.shared
    
    public init(navigation: NavigationModel) {
        self.navigation = navigation
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // App Branding Header
            HStack(spacing: 12) {
                TidyIcon("tidy-icon", size: 36, sfFallback: "sparkles")
                    .shadow(color: TidyTheme.primaryRose.opacity(0.18), radius: 8, y: 3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tidy")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text("Cleaner & Organizer")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.5)
            
            // Full Disk Access Banner if probe failed
            if !permissions.hasFullDiskAccess {
                Button(action: {
                    permissions.openSystemSettingsFullDiskAccess()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(TidyTheme.warningColor)
                            .font(.system(size: 13))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Limited Mode")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(TidyTheme.textPrimary)
                            Text("Click to grant Disk Access")
                                .font(.system(size: 10))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TidyTheme.warningColor.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            
            if storage.settings.dryRunMode {
                HStack(spacing: 6) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 10))
                    Text("Dry-Run Mode Active")
                        .font(.system(size: 10, weight: .bold))
                    Spacer()
                }
                .foregroundColor(TidyTheme.warningColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 3)
            }
            
            // Custom Fluid Navigation List with 100% full-width click target
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Group 1: Overview
                    VStack(alignment: .leading, spacing: 4) {
                        groupHeader("OVERVIEW")
                        sidebarRow(for: .dashboard)
                    }
                    
                    // Group 2: Clean & Optimize
                    VStack(alignment: .leading, spacing: 4) {
                        groupHeader("CLEAN & OPTIMIZE")
                        sidebarRow(for: .smartScan)
                        sidebarRow(for: .cacheCleaner)
                        sidebarRow(for: .largeFiles)
                        sidebarRow(for: .duplicates)
                    }
                    
                    // Group 3: Organize & Apps
                    VStack(alignment: .leading, spacing: 4) {
                        groupHeader("ORGANIZE & APPS")
                        sidebarRow(for: .downloads)
                        sidebarRow(for: .downloadsOrganizer)
                        sidebarRow(for: .uninstaller)
                        sidebarRow(for: .startupItems)
                    }
                    
                    // Group 4: Activity & Preferences
                    VStack(alignment: .leading, spacing: 4) {
                        groupHeader("MANAGE")
                        sidebarRow(for: .history)
                        sidebarRow(for: .settings)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            
            Divider()
                .opacity(0.5)
            
            // Storage Footer Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mac Storage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(TidyTheme.textSecondary)
                    Spacer()
                    Text(diskInfo.formattedFree + " free")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(TidyTheme.primaryRose)
                }
                
                StorageProgressBar(usedPercentage: diskInfo.usedPercentage, height: 6)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(TidyTheme.roseChipBg)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 230, maxWidth: 260)
        .background(TidyTheme.sidebarBackground)
    }
    
    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundColor(TidyTheme.textMuted)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
    
    private func sidebarRow(for item: SidebarItem) -> some View {
        let isSelected = navigation.selectedItem == item
        
        return Button(action: {
            navigation.selectedItem = item
        }) {
            HStack(spacing: 11) {
                // Real squircle icon in full 32-bit RGBA color
                TidyIcon(item.iconName, size: 24, sfFallback: item.sfFallback)
                
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? TidyTheme.textPrimary : TidyTheme.textSecondary)
                
                Spacer()
                
                if item == .downloads && downloadEngine.activeCount > 0 {
                    Text("\(downloadEngine.activeCount)")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(TidyTheme.primaryRose))
                }
                
                if isSelected {
                    Circle()
                        .fill(TidyTheme.primaryRose)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // Entire row is 100% clickable from left to right!
        }
        .buttonStyle(SidebarRowButtonStyle(isSelected: isSelected))
    }
}

public struct SidebarRowButtonStyle: ButtonStyle {
    public let isSelected: Bool
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? TidyTheme.roseLight : (configuration.isPressed ? TidyTheme.roseChipBg : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? TidyTheme.roseSoftBorder : Color.clear, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.88 : 1.0)
    }
}
