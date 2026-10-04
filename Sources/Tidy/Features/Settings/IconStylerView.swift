import SwiftUI
import AppKit

@MainActor
public class IconStylerViewModel: ObservableObject {
    @Published public var targetPath: String = ""
    @Published public var targetName: String = "No item selected"
    @Published public var targetKind: String = "Folder / App / File"
    @Published public var targetCurrentIcon: NSImage? = nil
    
    @Published public var selectedNewImage: NSImage? = nil
    @Published public var selectedIconItemName: String? = nil
    @Published public var statusFeedback: String? = nil
    @Published public var isShowingIconPicker: Bool = false
    @Published public var isTargetHovered: Bool = false
    @Published public var isApplying: Bool = false
    
    public init() {}
    
    public func setTarget(url: URL) {
        self.targetPath = url.path
        self.targetName = url.lastPathComponent
        
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        if url.pathExtension.lowercased() == "app" {
            self.targetKind = "macOS Application"
        } else if isDir.boolValue {
            self.targetKind = "Folder"
        } else {
            self.targetKind = "File (\(url.pathExtension.uppercased()))"
        }
        
        self.targetCurrentIcon = NSWorkspace.shared.icon(forFile: url.path)
        self.statusFeedback = nil
    }
}

public struct IconStylerView: View {
    @ObservedObject var packManager = IconPackManager.shared
    @StateObject private var viewModel = IconStylerViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                TidyIcon("tidy-folder-icon", size: 36, sfFallback: "paintpalette.fill")
                    .shadow(color: TidyTheme.primaryRose.opacity(0.18), radius: 6, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Icon Styler & Changer")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text("Change icons for any Folder, File, or macOS Application across your Mac.")
                        .font(.system(size: 12))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                // Wallpapers Clan Button
                Button(action: {
                    packManager.openWallpapersClan()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 11))
                        Text("Wallpapers Clan")
                            .font(.system(size: 11.5, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(TidyTheme.primaryRose)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(TidyTheme.roseLight)
                            .overlay(Capsule().stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .help("Download free high-resolution icon packs from Wallpapers Clan")
            }
            
            // Drop target card
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    // Current Icon
                    if let icon = viewModel.targetCurrentIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(TidyTheme.innerCardBackground)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus.square.dashed")
                                    .font(.system(size: 24))
                                    .foregroundColor(TidyTheme.primaryRose.opacity(0.6))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.targetName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(TidyTheme.textPrimary)
                            .lineLimit(1)
                        
                        if !viewModel.targetPath.isEmpty {
                            Text(viewModel.targetPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(TidyTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Drag and drop any folder, file, or .app here, or click Browse")
                                .font(.system(size: 12))
                                .foregroundColor(TidyTheme.textMuted)
                        }
                        
                        HStack(spacing: 6) {
                            Text(viewModel.targetKind)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(TidyTheme.primaryRose)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(TidyTheme.roseLight))
                            
                            if let feedback = viewModel.statusFeedback {
                                Text(feedback)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(TidyTheme.successColor)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("Browse Target...") {
                        chooseTargetDialog()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                // If a new icon is selected, show side-by-side comparison
                if let newImg = viewModel.selectedNewImage {
                    HStack(spacing: 12) {
                        Text("New Icon to Apply:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        Image(nsImage: newImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                        
                        if let name = viewModel.selectedIconItemName {
                            Text(name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(TidyTheme.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button(action: applyNewIcon) {
                            HStack(spacing: 6) {
                                if viewModel.isApplying {
                                    MicroLoaderView(size: 14)
                                } else {
                                    Image(systemName: "checkmark")
                                }
                                Text("Apply Icon")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(TidyTheme.primaryGradient)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isApplying || viewModel.targetPath.isEmpty)
                        
                        Button("Revert Default") {
                            revertDefault()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.targetPath.isEmpty)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(TidyTheme.roseLight.opacity(0.7))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(TidyTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.isTargetHovered ? TidyTheme.primaryRose : TidyTheme.roseSoftBorder, lineWidth: viewModel.isTargetHovered ? 1.5 : 1)
                    )
                    .shadow(color: TidyTheme.cardShadow, radius: 8, y: 2)
            )
            .onDrop(of: ["public.file-url"], isTargeted: $viewModel.isTargetHovered) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            viewModel.setTarget(url: url)
                        }
                    }
                }
                return true
            }
            
            // Icon Packs Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ICON PACKS LIBRARY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        Text("\(packManager.installedPacks.count) packs loaded • \(packManager.installedPacks.reduce(0) { $0 + $1.totalIcons }) icons available")
                            .font(.system(size: 11))
                            .foregroundColor(TidyTheme.textMuted)
                    }
                    
                    Spacer()
                    
                    Button(action: importZipDialog) {
                        HStack(spacing: 5) {
                            if packManager.isImporting {
                                MicroLoaderView(size: 13)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Import Pack (.zip)")
                                .font(.system(size: 11.5, weight: .semibold))
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
                    .disabled(packManager.isImporting)
                    
                    Button("Full Gallery...") {
                        viewModel.isShowingIconPicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // Quick Picker Preview Grid of loaded icons
                let sampleIcons = Array(packManager.installedPacks.flatMap { $0.categories.flatMap { $0.icons } }.prefix(14))
                if sampleIcons.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 24))
                                .foregroundColor(TidyTheme.textMuted)
                            Text("No icon packs installed yet.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(TidyTheme.textSecondary)
                            Button("Download Free Packs (Wallpapers Clan)") {
                                packManager.openWallpapersClan()
                            }
                            .buttonStyle(.link)
                        }
                        Spacer()
                    }
                    .padding(20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sampleIcons) { iconItem in
                                Button(action: {
                                    if let img = iconItem.image {
                                        viewModel.selectedNewImage = img
                                        viewModel.selectedIconItemName = "\(iconItem.packName) • \(iconItem.name)"
                                    }
                                }) {
                                    VStack(spacing: 6) {
                                        if let img = iconItem.image {
                                            Image(nsImage: img)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 44, height: 44)
                                                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                                        }
                                        Text(iconItem.name)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(TidyTheme.textPrimary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 70)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(TidyTheme.innerCardBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(viewModel.selectedIconItemName?.contains(iconItem.name) == true ? TidyTheme.primaryRose : TidyTheme.roseSoftBorder, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
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
        .sheet(isPresented: $viewModel.isShowingIconPicker) {
            IconPickerSheet(
                targetTitle: viewModel.targetName.isEmpty ? "Selected Item" : viewModel.targetName,
                targetPath: viewModel.targetPath.isEmpty ? "/Users/\(NSUserName())" : viewModel.targetPath,
                onSelectImage: { img in
                    viewModel.selectedNewImage = img
                    viewModel.selectedIconItemName = "Custom Gallery Icon"
                },
                onSelectFile: { url in
                    if let img = NSImage(contentsOf: url) {
                        viewModel.selectedNewImage = img
                        viewModel.selectedIconItemName = url.lastPathComponent
                    }
                },
                onResetDefault: {
                    revertDefault()
                }
            )
        }
    }
    
    private func chooseTargetDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Target"
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setTarget(url: url)
        }
    }
    
    private func applyNewIcon() {
        guard let img = viewModel.selectedNewImage, !viewModel.targetPath.isEmpty else { return }
        viewModel.isApplying = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let ok = packManager.applyIcon(image: img, to: viewModel.targetPath)
            viewModel.isApplying = false
            if ok {
                viewModel.targetCurrentIcon = NSWorkspace.shared.icon(forFile: viewModel.targetPath)
                viewModel.statusFeedback = "Applied icon to \(viewModel.targetName) ✨"
            } else {
                viewModel.statusFeedback = "Failed to apply icon"
            }
        }
    }
    
    private func revertDefault() {
        guard !viewModel.targetPath.isEmpty else { return }
        _ = packManager.resetIcon(for: viewModel.targetPath)
        viewModel.targetCurrentIcon = NSWorkspace.shared.icon(forFile: viewModel.targetPath)
        viewModel.selectedNewImage = nil
        viewModel.selectedIconItemName = nil
        viewModel.statusFeedback = "Restored default icon for \(viewModel.targetName)"
    }
    
    private func importZipDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip]
        panel.prompt = "Import Icon Pack"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                _ = await packManager.importPack(from: url)
            }
        }
    }
}
