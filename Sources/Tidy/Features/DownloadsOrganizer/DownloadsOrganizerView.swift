import SwiftUI
import AppKit

public struct DownloadsOrganizerView: View {
    @ObservedObject var storage = StorageManager.shared
    @StateObject private var viewModel = DownloadsOrganizerViewModel()
    @ObservedObject var packManager = IconPackManager.shared
    
    private let categories = [
        "Images", "Docs", "Sheets", "Slides", "Archives",
        "Install", "Video", "Audio", "Code", "Other"
    ]
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Title with Wallpapers Clan shortcut
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Downloads Organizer")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(TidyTheme.textPrimary)
                        Text("Automatically routes downloaded files into organized subfolders and customizes their folder icons.")
                            .font(.system(size: 13))
                            .foregroundColor(TidyTheme.textSecondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        packManager.openWallpapersClan()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.fill.badge.plus")
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
                    .help("Download free high-resolution folder icons from Wallpapers Clan")
                }
                
                // Status / Overview Banner with PROMINENT AND ALWAYS VISIBLE tidy-downloads-organized.webp!
                HStack(spacing: 16) {
                    // Authentic Animated WebP Mascot (ALWAYS VISIBLE)
                    AnimatedWebPView("tidy-downloads-organized.webp")
                        .frame(width: 76, height: 76)
                        .shadow(color: TidyTheme.primaryRose.opacity(0.18), radius: 8, y: 3)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Watched Folder:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(TidyTheme.textSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            Text(storage.settings.downloadsWatchedPath)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(TidyTheme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(TidyTheme.innerCardBackground)
                                )
                            
                            Button(action: chooseWatchedFolder) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                    Text("Change")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(TidyTheme.primaryRose)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(TidyTheme.roseLight)
                                        .overlay(Capsule().stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if viewModel.looseFilesCount > 0 {
                            HStack(spacing: 6) {
                                Circle().fill(TidyTheme.primaryRose).frame(width: 8, height: 8)
                                Text("Found \(viewModel.looseFilesCount) loose files (\(ByteCountFormatter.string(fromByteCount: viewModel.looseFilesSizeBytes, countStyle: .file))) ready to organize")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(TidyTheme.primaryRose)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Circle().fill(TidyTheme.successColor).frame(width: 8, height: 8)
                                Text("Folder is perfectly organized • No loose files")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(TidyTheme.successColor)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.isScanning {
                        MicroLoaderView(size: 24)
                            .padding(.trailing, 8)
                    } else {
                        Button(action: {
                            viewModel.refreshLooseFiles()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(TidyTheme.textSecondary)
                                .padding(8)
                                .background(Circle().fill(TidyTheme.roseChipBg))
                        }
                        .buttonStyle(.plain)
                        .help("Refresh folder contents")
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
                )
                
                // Automation Toggles
                HStack(spacing: 24) {
                    HStack(spacing: 10) {
                        Text("Auto-organize new downloads:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TidyTheme.textPrimary)
                            .fixedSize(horizontal: true, vertical: false)
                        Toggle("", isOn: Binding(
                            get: { storage.settings.autoOrganizeDownloads },
                            set: { newValue in
                                storage.settings.autoOrganizeDownloads = newValue
                                storage.saveSettings()
                                if newValue {
                                    DownloadsWatcher.shared.startWatching(path: storage.settings.downloadsWatchedPath)
                                } else {
                                    DownloadsWatcher.shared.stopWatching()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .tint(TidyTheme.primaryRose)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Organize files older than:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TidyTheme.textPrimary)
                            .fixedSize(horizontal: true, vertical: false)
                        Picker("", selection: Binding(
                            get: { storage.settings.organizeMinAgeDays },
                            set: { newValue in
                                storage.settings.organizeMinAgeDays = newValue
                                storage.saveSettings()
                                viewModel.refreshLooseFiles()
                            }
                        )) {
                            Text("Immediately (0 days)").tag(0)
                            Text("1 day").tag(1)
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                        }
                        .labelsHidden()
                        .frame(width: 175)
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
                
                // Rules Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RULES (applied top to bottom, first match wins)")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        Spacer()
                        Button(action: {
                            viewModel.isShowingRuleEditor = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add rule")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(TidyTheme.primaryRose)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(storage.rules.indices, id: \.self) { idx in
                            let rule = storage.rules[idx]
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { rule.isEnabled },
                                    set: { val in
                                        storage.rules[idx].isEnabled = val
                                        storage.saveRules()
                                        viewModel.refreshLooseFiles()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                
                                TidyIcon(categoryIconName(rule.destinationSubfolder), size: 24, sfFallback: "folder.fill")
                                
                                Text(rule.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(TidyTheme.textPrimary)
                                    .frame(width: 110, alignment: .leading)
                                
                                Text(rule.matchType == .everythingElse ? "Everything else" : "ext: \(rule.matchValue)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(TidyTheme.textSecondary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(TidyTheme.textMuted)
                                
                                Text(rule.destinationSubfolder)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(TidyTheme.primaryRose)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(TidyTheme.roseLight))
                                    .frame(width: 100, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(TidyTheme.innerCardBackground)
                            )
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
                )
                
                // Destination Root & Root Folder Icon Customizer
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("Destination root:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(TidyTheme.textSecondary)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        Text(storage.settings.downloadsDestinationPath)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(TidyTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(TidyTheme.innerCardBackground)
                            )
                        
                        Button(action: chooseDestinationFolder) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                Text("Change")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.primaryRose)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(TidyTheme.roseLight)
                                    .overlay(Capsule().stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Root /Sorted Icon Customizer Row
                    HStack(spacing: 12) {
                        let _ = viewModel.folderIconUpdateTrigger
                        let folderIcon = NSWorkspace.shared.icon(forFile: storage.settings.downloadsDestinationPath)
                        Image(nsImage: folderIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Root Folder Icon (/Sorted):")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(TidyTheme.textPrimary)
                                
                                if let msg = viewModel.folderIconStatusMessage {
                                    Text(msg)
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(TidyTheme.primaryRose)
                                }
                            }
                            
                            Text("Set custom icon for \(URL(fileURLWithPath: storage.settings.downloadsDestinationPath).lastPathComponent) in macOS Finder.")
                                .font(.system(size: 11))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.applyTidyIcon(to: storage.settings.downloadsDestinationPath)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10.5))
                                Text("Tidy Icon")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundColor(TidyTheme.primaryRose)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(TidyTheme.roseLight)
                                    .overlay(Capsule().stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            viewModel.isShowingRootPicker = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 10.5))
                                Text("Icon Gallery...")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: {
                            viewModel.resetToDefaultIcon(for: storage.settings.downloadsDestinationPath)
                        }) {
                            Text("Default")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(TidyTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.buildPreview()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "eye")
                                Text("Preview Move")
                            }
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(TidyTheme.primaryGradient)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
                )
                
                // NEW: Subfolder Icon Setter for Downloads under /Sorted (Images, Audio, Docs, etc.)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CATEGORY SUBFOLDER ICONS (/Sorted/...)")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(TidyTheme.textSecondary)
                            Text("Customize the Finder icon for each organized category subfolder.")
                                .font(.system(size: 11))
                                .foregroundColor(TidyTheme.textMuted)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            packManager.openWallpapersClan()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                Text("Wallpapers Clan Packs")
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9))
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(TidyTheme.primaryRose)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 12)], spacing: 12) {
                        ForEach(categories, id: \.self) { cat in
                            let _ = viewModel.folderIconUpdateTrigger
                            let path = viewModel.subfolderPath(for: cat)
                            let currentIcon = NSWorkspace.shared.icon(forFile: path)
                            
                            HStack(spacing: 12) {
                                Image(nsImage: currentIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    
                                    Text("/Sorted/\(cat)")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(TidyTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.selectedSubfolderForPicker = cat
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 10))
                                        Text("Pick Icon")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button(action: {
                                    viewModel.resetSubfolderIcon(category: cat)
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10))
                                        .foregroundColor(TidyTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reset \(cat) to default macOS icon")
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(TidyTheme.innerCardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
                )
            }
            .padding(28)
        }
        .background(TidyTheme.windowBackground)
        .sheet(isPresented: $viewModel.isShowingPreviewSheet) {
            MovePreviewSheet(
                plan: viewModel.currentPlan,
                onCancel: {
                    viewModel.isShowingPreviewSheet = false
                },
                onConfirm: {
                    viewModel.executeOrganize()
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingRuleEditor) {
            RulesEditorSheet(isPresented: $viewModel.isShowingRuleEditor) { newRule in
                storage.rules.append(newRule)
                storage.saveRules()
                viewModel.refreshLooseFiles()
            }
        }
        .sheet(isPresented: $viewModel.isShowingRootPicker) {
            IconPickerSheet(
                targetTitle: "Destination Root (/Sorted)",
                targetPath: storage.settings.downloadsDestinationPath,
                onSelectImage: { img in
                    _ = packManager.applyIcon(image: img, to: storage.settings.downloadsDestinationPath)
                    viewModel.folderIconUpdateTrigger = UUID()
                },
                onSelectFile: { url in
                    _ = packManager.applyIcon(from: url, to: storage.settings.downloadsDestinationPath)
                    viewModel.folderIconUpdateTrigger = UUID()
                },
                onResetDefault: {
                    viewModel.resetToDefaultIcon(for: storage.settings.downloadsDestinationPath)
                }
            )
        }
        .sheet(item: Binding<IdentifiableCategory?>(
            get: {
                viewModel.selectedSubfolderForPicker.map { IdentifiableCategory(id: $0) }
            },
            set: {
                viewModel.selectedSubfolderForPicker = $0?.id
            }
        )) { cat in
            let path = viewModel.subfolderPath(for: cat.id)
            IconPickerSheet(
                targetTitle: "Subfolder '\(cat.id)'",
                targetPath: path,
                onSelectImage: { img in
                    viewModel.applySubfolderIcon(image: img, category: cat.id)
                },
                onSelectFile: { url in
                    viewModel.applySubfolderIcon(from: url, category: cat.id)
                },
                onResetDefault: {
                    viewModel.resetSubfolderIcon(category: cat.id)
                }
            )
        }
    }
    
    private func categoryIconName(_ folder: String) -> String {
        switch folder.lowercased() {
        case "images": return "cat-images"
        case "docs", "documents": return "cat-documents"
        case "sheets": return "cat-sheets"
        case "slides": return "cat-slides"
        case "archives": return "cat-archives"
        case "install", "installers": return "cat-installers"
        case "video": return "cat-video"
        case "audio": return "cat-audio"
        case "code": return "cat-code"
        default: return "cat-other"
        }
    }
    
    private func chooseWatchedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            storage.settings.downloadsWatchedPath = url.path
            storage.saveSettings()
            viewModel.refreshLooseFiles()
        }
    }
    
    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            storage.settings.downloadsDestinationPath = url.path
            storage.saveSettings()
            viewModel.folderIconUpdateTrigger = UUID()
        }
    }
}

public struct IdentifiableCategory: Identifiable {
    public let id: String
    public init(id: String) { self.id = id }
}
