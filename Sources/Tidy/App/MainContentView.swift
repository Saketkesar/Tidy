import SwiftUI

public struct MainContentView: View {
    @StateObject private var navigation = NavigationModel()
    @ObservedObject var permissions = PermissionManager.shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if !permissions.hasFullDiskAccess && !navigation.hasDismissedPermissionOnboarding {
                PermissionView(onDismissLimitedMode: {
                    navigation.hasDismissedPermissionOnboarding = true
                })
            } else {
                NavigationSplitView {
                    SidebarView(navigation: navigation)
                } detail: {
                    detailView(for: navigation.selectedItem)
                        .frame(minWidth: 680, minHeight: 580)
                        .background(TidyTheme.windowBackground)
                }
                .navigationSplitViewStyle(.balanced)
                .environmentObject(navigation)
            }
        }
        .frame(minWidth: 920, minHeight: 640)
        .background(TidyTheme.windowBackground)
        .preferredColorScheme(.light)
    }
    
    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .smartScan:
            SmartScanView()
        case .cacheCleaner:
            CacheCleanerView()
        case .largeFiles:
            LargeFilesView()
        case .duplicates:
            DuplicatesView()
        case .downloads:
            DownloadsView()
        case .downloadsOrganizer:
            DownloadsOrganizerView()
        case .uninstaller:
            UninstallerView()
        case .startupItems:
            StartupItemsView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}
