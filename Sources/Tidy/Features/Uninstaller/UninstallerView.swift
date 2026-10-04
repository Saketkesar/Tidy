import SwiftUI
import AppKit

public struct UninstallerView: View {
    @StateObject private var viewModel = UninstallerViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header & Search
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("App Uninstaller")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Completely removes applications along with their hidden caches, containers, and leftovers.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                // Modern Styled Search Bar
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TidyTheme.textMuted)
                    TextField("Search apps...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(TidyTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                )
                .frame(width: 200)
                
                // Fixed Sort Segmented Control (Never wraps)
                HStack(spacing: 6) {
                    Text("Sort:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TidyTheme.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                    Picker("", selection: $viewModel.sortBySize) {
                        Text("Size").tag(true)
                        Text("Name").tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .fixedSize(horizontal: true, vertical: false)
                
                Button(action: {
                    viewModel.scanInstalledApps()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(TidyTheme.textSecondary)
                        .padding(6)
                        .background(Circle().fill(TidyTheme.roseChipBg))
                }
                .buttonStyle(.plain)
                .help("Refresh installed apps")
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .opacity(0.5)
            
            if viewModel.isScanning {
                VStack(spacing: 14) {
                    Spacer()
                    AnimatedWebPView("tidy-uninstaller.webp")
                        .frame(width: 170, height: 170)
                    Text("Scanning installed applications and leftovers...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    // Left Column: App List
                    List(selection: Binding(
                        get: { viewModel.selectedApp?.id },
                        set: { newId in
                            if let id = newId, let app = viewModel.apps.first(where: { $0.id == id }) {
                                viewModel.selectApp(app)
                            }
                        }
                    )) {
                        ForEach(viewModel.filteredApps) { app in
                            HStack(spacing: 10) {
                                FileIconView(url: app.bundleURL)
                                    .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(app.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(TidyTheme.textPrimary)
                                        if app.isRunning {
                                            Text("Running")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(TidyTheme.warningColor.opacity(0.18)))
                                                .foregroundColor(TidyTheme.warningColor)
                                        }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(TidyTheme.textSecondary)
                                        if app.totalLeftoverSize > 0 {
                                            Text("+ \(ByteCountFormatter.string(fromByteCount: app.totalLeftoverSize, countStyle: .file)) leftovers")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(TidyTheme.primaryRose)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .tag(app.id)
                        }
                    }
                    .frame(minWidth: 260, maxWidth: 360)
                    
                    // Right Column: App Detail & Leftovers Inspector
                    if let app = viewModel.selectedApp {
                        appDetailView(app: app)
                    } else {
                        VStack(spacing: 14) {
                            Spacer()
                            AnimatedWebPView("tidy-uninstaller.webp")
                                .frame(width: 140, height: 140)
                            Text("Select an application to view bundle details and leftovers")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(TidyTheme.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(TidyTheme.windowBackground)
        .confirmationDialog(
            "Move \(viewModel.selectedApp?.name ?? "App") and selected leftovers to Trash?",
            isPresented: $viewModel.isShowingConfirmSheet,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    await viewModel.uninstallSelectedApp()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The application bundle and its matched leftovers will be moved to macOS Trash. You can undo this action from History.")
        }
    }
    
    private func appDetailView(app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Info Header Card
            HStack(spacing: 14) {
                FileIconView(url: app.bundleURL)
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    if let bid = app.bundleId {
                        Text(bid)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(TidyTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                if app.isRunning {
                    Button(action: {
                        viewModel.quitRunningApp()
                    }) {
                        Text("Quit App")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
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
            )
            
            // App Bundle Path Card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Bundle")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(TidyTheme.textSecondary)
                    Text(app.bundleURL.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TidyTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(TidyTheme.textPrimary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(TidyTheme.innerCardBackground)
            )
            
            // Leftovers List
            VStack(alignment: .leading, spacing: 10) {
                Text("Leftovers found (matched by exact bundle ID):")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(TidyTheme.textPrimary)
                
                if app.leftovers.isEmpty {
                    Text("No leftover files found in standard Library paths.")
                        .font(.system(size: 12))
                        .foregroundColor(TidyTheme.textSecondary)
                        .padding(.vertical, 6)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(app.leftovers.indices, id: \.self) { idx in
                                let leftover = app.leftovers[idx]
                                HStack(spacing: 10) {
                                    Toggle("", isOn: Binding(
                                        get: { leftover.isSelected },
                                        set: { val in
                                            if let aIdx = viewModel.apps.firstIndex(where: { $0.id == app.id }) {
                                                viewModel.apps[aIdx].leftovers[idx].isSelected = val
                                                viewModel.selectedApp?.leftovers[idx].isSelected = val
                                            }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(leftover.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(TidyTheme.textPrimary)
                                        Text(leftover.path)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(TidyTheme.textSecondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: leftover.sizeBytes, countStyle: .file))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(TidyTheme.textSecondary)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(TidyTheme.innerCardBackground)
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 220)
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
            )
            
            Spacer()
            
            // Bottom Action
            HStack {
                Spacer()
                Button(action: {
                    viewModel.isShowingConfirmSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Move app + leftovers to Trash")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TidyTheme.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
    }
}
