import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case iconStyler = "Icon Packs & Styler"
    case cleaning = "Cleaning & Safety"
    case downloads = "Downloads"
    case permissions = "Permissions"
    case data = "About & Community"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .iconStyler: return "paintpalette.fill"
        case .cleaning: return "shield.lefthalf.filled"
        case .downloads: return "folder.badge.gearshape"
        case .permissions: return "lock.shield.fill"
        case .data: return "person.crop.circle.fill"
        }
    }
}

@MainActor
public class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: SettingsTab = .general
    @Published public var showingResetConfirm: Bool = false
    @Published public var isExporting: Bool = false
    @Published public var isRecheckingPermissions: Bool = false
    @Published public var exportMessage: String? = nil
    
    public init() {}
}

public struct SettingsView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var permissions = PermissionManager.shared
    @ObservedObject var packManager = IconPackManager.shared
    @ObservedObject var updater = AppUpdateService.shared
    @StateObject private var viewModel = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text("Configure your Mac cleaner, customize folder & app icons, and control automation.")
                        .font(.system(size: 12.5))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                // Wallpapers Clan quick link pill
                Button(action: {
                    packManager.openWallpapersClan()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 11))
                        Text("Wallpapers Clan Icons")
                            .font(.system(size: 11.5, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(TidyTheme.primaryRose)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(TidyTheme.roseLight)
                            .overlay(Capsule().stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .help("Get free high quality folder and app icons from Wallpapers Clan")
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Tab Bar
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: viewModel.selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(viewModel.selectedTab == tab ? TidyTheme.primaryRose : TidyTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedTab == tab ? TidyTheme.roseLight : Color.clear)
                                .overlay(
                                    Capsule()
                                        .stroke(viewModel.selectedTab == tab ? TidyTheme.roseSoftBorder : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.4)
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    switch viewModel.selectedTab {
                    case .general:
                        generalSection
                    case .iconStyler:
                        iconStylerSection
                    case .cleaning:
                        cleaningSafetySection
                    case .downloads:
                        downloadsSection
                    case .permissions:
                        permissionsSection
                    case .data:
                        dataSection
                    }
                }
                .padding(28)
            }
        }
        .background(TidyTheme.windowBackground)
        .confirmationDialog(
            "Reset all settings and organizer rules to defaults?",
            isPresented: $viewModel.showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                storage.resetAllSettings()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - 1. General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(
                title: "General Preferences",
                subtitle: "System startup and menu bar presence.",
                icon: "gearshape.2.fill"
            ) {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Launch at login",
                        subtitle: "Automatically start Tidy in background when you log into your Mac.",
                        isOn: Binding(
                            get: { storage.settings.launchAtLogin },
                            set: { val in
                                storage.settings.launchAtLogin = val
                                storage.saveSettings()
                            }
                        )
                    )
                    
                    Divider().opacity(0.4)
                    
                    toggleRow(
                        title: "Show available free space in menu bar",
                        subtitle: "Displays real-time disk storage in your macOS menu bar tray.",
                        isOn: Binding(
                            get: { storage.settings.showFreeSpaceInMenuBar },
                            set: { val in
                                storage.settings.showFreeSpaceInMenuBar = val
                                storage.saveSettings()
                            }
                        )
                    )
                }
            }
            
            settingsCard(
                title: "Notifications",
                subtitle: "Control desktop alerts and activity toasts.",
                icon: "bell.badge.fill"
            ) {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Downloads organizer activity",
                        subtitle: "Notify when loose downloads are automatically sorted into categories.",
                        isOn: Binding(
                            get: { storage.settings.notifyOrganizerActivity },
                            set: { val in
                                storage.settings.notifyOrganizerActivity = val
                                storage.saveSettings()
                            }
                        )
                    )
                    
                    Divider().opacity(0.4)
                    
                    toggleRow(
                        title: "Low disk space alert",
                        subtitle: "Send a warning when available free storage drops below 10%.",
                        isOn: Binding(
                            get: { storage.settings.notifyLowDiskSpace },
                            set: { val in
                                storage.settings.notifyLowDiskSpace = val
                                storage.saveSettings()
                            }
                        )
                    )
                }
            }
        }
    }
    
    // MARK: - 2. Icon Packs & Mac Styler Section
    private var iconStylerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Wallpapers Clan Feature Banner with Authentic Logo & User Text
            HStack(spacing: 16) {
                // Authentic Wallpapers Clan Logo
                let wClanImage = loadWallpapersClanLogo()
                if let img = wClanImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .padding(5)
                        .background(Circle().fill(Color.black))
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                } else {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 32))
                        .foregroundColor(TidyTheme.primaryRose)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Wallpapers Clan Icon Packs")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(TidyTheme.textPrimary)
                        
                        Text("Free & High Quality")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(TidyTheme.primaryRose)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(TidyTheme.roseLight))
                    }
                    
                    Text("https://wallpapers-clan.com/folder-icons/ — This is not sponsored, but I like it and it's the best so use accordingly! Download high-resolution anime, aesthetic, and custom Mac folder & app icons.")
                        .font(.system(size: 11.5))
                        .foregroundColor(TidyTheme.textSecondary)
                        .lineSpacing(2)
                }
                
                Spacer()
                
                Button(action: {
                    packManager.openWallpapersClan()
                }) {
                    HStack(spacing: 6) {
                        Text("Explore Icons")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(TidyTheme.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(TidyTheme.subtlePinkGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                    )
            )
            
            // Full Mac-Wide Icon Styler Component
            IconStylerView()
        }
    }
    
    // MARK: - 3. Cleaning & Safety Section
    private var cleaningSafetySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(
                title: "Safety Thresholds",
                subtitle: "Safe by default. Standard macOS protection and simulation modes.",
                icon: "shield.checkered"
            ) {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Dry-run mode",
                        subtitle: "Scans and reports everything accurately but simulates deletion without touching files.",
                        isOn: Binding(
                            get: { storage.settings.dryRunMode },
                            set: { val in
                                storage.settings.dryRunMode = val
                                storage.saveSettings()
                            }
                        )
                    )
                    
                    Divider().opacity(0.4)
                    
                    toggleRow(
                        title: "Allow permanent delete",
                        subtitle: "Permanently unlink files immediately instead of moving them to macOS Trash (use with care).",
                        isOn: Binding(
                            get: { storage.settings.allowPermanentDelete },
                            set: { val in
                                storage.settings.allowPermanentDelete = val
                                storage.saveSettings()
                            }
                        ),
                        isDestructive: true
                    )
                }
            }
            
            settingsCard(
                title: "User Protected Folders",
                subtitle: "Folders in this list are strictly blacklisted from being cleaned or deleted.",
                icon: "lock.fill"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Protected Locations (\(storage.settings.userProtectedPaths.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(TidyTheme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: addProtectedFolder) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Protected Folder")
                            }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(TidyTheme.primaryRose)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if storage.settings.userProtectedPaths.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(TidyTheme.successColor)
                            Text("Standard macOS system directories, iCloud containers, and user identity paths are protected by default.")
                                .font(.system(size: 11.5))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(TidyTheme.innerCardBackground)
                        )
                    } else {
                        VStack(spacing: 6) {
                            ForEach(storage.settings.userProtectedPaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(TidyTheme.primaryRose)
                                        .font(.system(size: 12))
                                    Text(path)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    Spacer()
                                    Button(action: {
                                        storage.settings.userProtectedPaths.removeAll { $0 == path }
                                        storage.saveSettings()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(TidyTheme.textMuted)
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
                }
            }
        }
    }
    
    // MARK: - 4. Downloads Section
    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(
                title: "Downloads Automation",
                subtitle: "Configure where files land and how loose downloads are sorted.",
                icon: "folder.fill.badge.gearshape"
            ) {
                VStack(spacing: 14) {
                    toggleRow(
                        title: "Auto-organize new downloads",
                        subtitle: "Watches your Downloads folder and categorizes new incoming files automatically.",
                        isOn: Binding(
                            get: { storage.settings.autoOrganizeDownloads },
                            set: { val in
                                storage.settings.autoOrganizeDownloads = val
                                storage.saveSettings()
                                if val {
                                    DownloadsWatcher.shared.startWatching(path: storage.settings.downloadsWatchedPath)
                                } else {
                                    DownloadsWatcher.shared.stopWatching()
                                }
                            }
                        )
                    )
                    
                    Divider().opacity(0.4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Organize files older than:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(TidyTheme.textPrimary)
                            Text("Delay organizing recent downloads so in-progress work isn't moved.")
                                .font(.system(size: 11.5))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { storage.settings.organizeMinAgeDays },
                            set: { val in
                                storage.settings.organizeMinAgeDays = val
                                storage.saveSettings()
                            }
                        )) {
                            Text("Immediately (0 days)").tag(0)
                            Text("1 day").tag(1)
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                    
                    Divider().opacity(0.4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Destination folder root:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(TidyTheme.textPrimary)
                            Text(storage.settings.downloadsDestinationPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(TidyTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button("Change...") {
                            chooseDestinationFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(
                title: "macOS Full Disk Access",
                subtitle: "Required to scan caches, find duplicate files, and organize protected folders.",
                icon: "lock.shield.fill"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(permissions.hasFullDiskAccess ? TidyTheme.successColor : TidyTheme.warningColor)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(permissions.hasFullDiskAccess ? "Full Disk Access: Active" : "Full Disk Access: Not Granted Yet")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(TidyTheme.textPrimary)
                            
                            Text(permissions.hasFullDiskAccess ? "Tidy has complete permission to clean caches and manage folders." : "Grant Full Disk Access in macOS System Settings for complete capability.")
                                .font(.system(size: 11.5))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.isRecheckingPermissions {
                            MicroLoaderView(size: 18)
                        } else {
                            Button("Recheck") {
                                viewModel.isRecheckingPermissions = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    permissions.checkFullDiskAccess()
                                    viewModel.isRecheckingPermissions = false
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        if !permissions.hasFullDiskAccess {
                            Button("Open System Settings") {
                                permissions.openSystemSettingsFullDiskAccess()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TidyTheme.primaryRose)
                            .controlSize(.small)
                        }
                    }
                    
                    Divider().opacity(0.4)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(TidyTheme.primaryRose)
                            .font(.system(size: 12))
                        Text("100% Offline Guarantee: Tidy never sends file names, URLs, or metadata off your Mac. Zero tracking, zero telemetry.")
                            .font(.system(size: 11))
                            .foregroundColor(TidyTheme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 6. About, Developer, Community & Auto-Updates
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // App & Developer Info Card
            settingsCard(
                title: "Developer & Creator",
                subtitle: "Created with care for the Mac community.",
                icon: "person.crop.circle.fill"
            ) {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        TidyIcon("tidy-icon", size: 44, sfFallback: "sparkles")
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Tidy for macOS")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(TidyTheme.textPrimary)
                                
                                Text("v1.2.0")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(TidyTheme.primaryRose)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(TidyTheme.roseLight))
                            }
                            
                            Text("Created by Saket Kesar • Native Swift & SwiftUI • 100% Offline")
                                .font(.system(size: 12))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Contact Info & GitHub Profile
                    HStack(spacing: 12) {
                        Button(action: {
                            updater.openDeveloperGitHub()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                Text("GitHub: @Saketkesar")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.innerCardBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            updater.contactDeveloperEmail()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(TidyTheme.primaryRose)
                                Text("saketkesar391@gmail.com")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.innerCardBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
            }
            
            // Community, Bug Reports & Contributions Card
            settingsCard(
                title: "Feedback & Community",
                subtitle: "Direct links to report issues, request features, and contribute.",
                icon: "bubble.left.and.bubble.right.fill"
            ) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Report Bug
                        Button(action: {
                            updater.openReportBug()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "ladybug.fill")
                                    .foregroundColor(TidyTheme.dangerColor)
                                    .font(.system(size: 12))
                                Text("Report a Bug")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.cardBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Suggest Features
                        Button(action: {
                            updater.openSuggestFeature()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(TidyTheme.warningColor)
                                    .font(.system(size: 12))
                                Text("Suggest Features")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.cardBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Contribute
                        Button(action: {
                            updater.openContribute()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(TidyTheme.primaryRose)
                                    .font(.system(size: 12))
                                Text("Star & Contribute")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.cardBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
            }
            
            // Auto Update from GitHub Card
            settingsCard(
                title: "Software Updates",
                subtitle: "Direct updates from GitHub Releases.",
                icon: "arrow.triangle.2.circlepath.circle.fill"
            ) {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("GitHub Releases Auto-Updater")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(TidyTheme.textPrimary)
                                
                                if updater.updateAvailable {
                                    Text("NEW UPDATE AVAILABLE")
                                        .font(.system(size: 9.5, weight: .heavy))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(TidyTheme.primaryRose))
                                }
                            }
                            
                            if let msg = updater.statusMessage {
                                Text(msg)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(updater.updateAvailable ? TidyTheme.primaryRose : TidyTheme.textSecondary)
                            } else {
                                Text("Current version: v1.2.0 • Checks api.github.com/repos/Saketkesar/Tidy/releases/latest")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(TidyTheme.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        if updater.isChecking || updater.isDownloading {
                            MicroLoaderView(size: 20)
                                .padding(.horizontal, 8)
                        } else if updater.updateAvailable {
                            Button(action: {
                                updater.downloadAndInstallUpdate()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Install Update")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(TidyTheme.primaryGradient))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("Check for Updates") {
                                Task {
                                    await updater.checkForUpdates(manual: true)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    
                    Divider().opacity(0.4)
                    
                    toggleRow(
                        title: "Automatically check for updates on launch",
                        subtitle: "Silently checks for new Tidy releases when you open the app.",
                        isOn: Binding(
                            get: { storage.settings.autoCheckUpdates },
                            set: { val in
                                storage.settings.autoCheckUpdates = val
                                storage.saveSettings()
                            }
                        )
                    )
                }
            }
            
            // Backup & Factory Reset Card
            settingsCard(
                title: "History Backup & Reset",
                subtitle: "Export your cleaning logs or restore factory defaults.",
                icon: "arrow.triangle.2.circlepath"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Button(action: exportHistory) {
                            HStack(spacing: 6) {
                                if viewModel.isExporting {
                                    MicroLoaderView(size: 14)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text("Export Cleaning History (JSON)")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        
                        if let msg = viewModel.exportMessage {
                            Text(msg)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(TidyTheme.successColor)
                        }
                        
                        Spacer()
                        
                        Button("Reset All Settings...") {
                            viewModel.showingResetConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .foregroundColor(TidyTheme.dangerColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Reusable Card Builders
    
    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(TidyTheme.primaryRose)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(TidyTheme.roseLight))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                Spacer()
            }
            
            Divider().opacity(0.3)
            
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TidyTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                )
                .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
        )
    }
    
    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isDestructive: Bool = false
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDestructive && isOn.wrappedValue ? TidyTheme.dangerColor : TidyTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(TidyTheme.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(TidyTheme.primaryRose)
                .labelsHidden()
        }
    }
    
    private func loadWallpapersClanLogo() -> NSImage? {
        let directPath = "/Users/saketkesar/Downloads/dinly/Tidy/Resources/w-clan-logo.png"
        if FileManager.default.fileExists(atPath: directPath), let img = NSImage(contentsOfFile: directPath) {
            return img
        }
        if let resURL = Bundle.main.resourceURL {
            let bundleFile = resURL.appendingPathComponent("w-clan-logo.png")
            if FileManager.default.fileExists(atPath: bundleFile.path), let img = NSImage(contentsOf: bundleFile) {
                return img
            }
        }
        return nil
    }
    
    private func addProtectedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Protect Folder"
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !storage.settings.userProtectedPaths.contains(url.path) {
                    storage.settings.userProtectedPaths.append(url.path)
                }
            }
            storage.saveSettings()
        }
    }
    
    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Destination Root"
        if panel.runModal() == .OK, let url = panel.url {
            storage.settings.downloadsDestinationPath = url.path
            storage.saveSettings()
        }
    }
    
    private func exportHistory() {
        viewModel.isExporting = true
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "Tidy_History_\(Int(Date().timeIntervalSince1970)).json"
        
        if savePanel.runModal() == .OK, let dst = savePanel.url {
            let json = storage.exportHistoryJSON()
            try? json.data(using: .utf8)?.write(to: dst)
            viewModel.exportMessage = "History exported successfully!"
        }
        viewModel.isExporting = false
    }
}
