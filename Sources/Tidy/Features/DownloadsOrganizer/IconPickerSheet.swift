import SwiftUI
import AppKit

@MainActor
public class IconPickerViewModel: ObservableObject {
    @Published public var selectedPackId: String = "all"
    @Published public var selectedCategory: String = "all"
    @Published public var searchText: String = ""
    public init() {}
}

public struct IconPickerSheet: View {
    public let targetTitle: String
    public let targetPath: String
    public let onSelectImage: (NSImage) -> Void
    public let onSelectFile: (URL) -> Void
    public let onResetDefault: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var packManager = IconPackManager.shared
    @StateObject private var viewModel = IconPickerViewModel()
    
    public init(
        targetTitle: String,
        targetPath: String,
        onSelectImage: @escaping (NSImage) -> Void,
        onSelectFile: @escaping (URL) -> Void,
        onResetDefault: @escaping () -> Void
    ) {
        self.targetTitle = targetTitle
        self.targetPath = targetPath
        self.onSelectImage = onSelectImage
        self.onSelectFile = onSelectFile
        self.onResetDefault = onResetDefault
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 14) {
                // Live current icon
                let currentIcon = NSWorkspace.shared.icon(forFile: targetPath)
                Image(nsImage: currentIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 38, height: 38)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, y: 1)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Icon for \(targetTitle)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text(targetPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TidyTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                // Wallpaper Clan link button
                Button(action: {
                    packManager.openWallpapersClan()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 12))
                        Text("Wallpapers Clan")
                            .font(.system(size: 11.5, weight: .semibold))
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
                .help("Download free high-quality folder & app icon packs from Wallpapers Clan")
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(TidyTheme.primaryRose)
                .controlSize(.regular)
            }
            .padding(18)
            .background(TidyTheme.cardBackground)
            
            Divider()
                .opacity(0.4)
            
            // Toolbar: Pack Selector, Category Filter, Search, Import ZIP
            HStack(spacing: 12) {
                // Pack selector
                Menu {
                    Button("All Icon Packs") {
                        viewModel.selectedPackId = "all"
                    }
                    Divider()
                    ForEach(packManager.installedPacks) { pack in
                        Button(pack.name) {
                            viewModel.selectedPackId = pack.id
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundColor(TidyTheme.primaryRose)
                        Text(currentPackTitle)
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: 160)
                
                // Category Filter (Folder, App, File)
                Picker("", selection: $viewModel.selectedCategory) {
                    Text("All Types").tag("all")
                    Text("Folder Icons").tag("Folder Icons")
                    Text("App Icons").tag("App Icons")
                    Text("File Icons").tag("File Icons")
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
                
                // Import Pack .zip button
                Button(action: importZipDialog) {
                    HStack(spacing: 5) {
                        if packManager.isImporting {
                            MicroLoaderView(size: 14)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Import .zip Pack")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(TidyTheme.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(TidyTheme.innerCardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(packManager.isImporting)
                .help("Import any .zip icon pack from Wallpapers Clan or your computer")
                
                // Revert to Default button
                Button(action: {
                    onResetDefault()
                    dismiss()
                }) {
                    Text("Default Icon")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(TidyTheme.innerCardBackground)
            
            Divider()
                .opacity(0.3)
            
            // Icon Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let displayedIcons = filteredIcons
                    
                    if displayedIcons.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 38))
                                .foregroundColor(TidyTheme.textMuted)
                            
                            Text("No icons found in this category")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(TidyTheme.textPrimary)
                            
                            Text("Download free icon packs from Wallpapers Clan and import the .zip here.")
                                .font(.system(size: 12))
                                .foregroundColor(TidyTheme.textSecondary)
                            
                            HStack(spacing: 12) {
                                Button("Open Wallpapers Clan") {
                                    packManager.openWallpapersClan()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(TidyTheme.primaryRose)
                                
                                Button("Import .zip Pack...") {
                                    importZipDialog()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88, maximum: 110), spacing: 14)], spacing: 14) {
                            ForEach(displayedIcons) { iconItem in
                                IconGridCell(iconItem: iconItem) {
                                    if let img = iconItem.image {
                                        onSelectImage(img)
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .background(TidyTheme.windowBackground)
            
            // Bottom Bar: Upload Custom Image File & Wallpapers Clan credit
            Divider()
                .opacity(0.4)
            
            HStack(spacing: 14) {
                // Custom Image picker
                Button(action: pickCustomImageFile) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                        Text("Upload Custom Image (.png, .icns)...")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("Icon packs from Wallpapers Clan • Free & High Resolution")
                    .font(.system(size: 11))
                    .foregroundColor(TidyTheme.textMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(TidyTheme.cardBackground)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
    
    private var currentPackTitle: String {
        if viewModel.selectedPackId == "all" { return "All Packs" }
        return packManager.installedPacks.first(where: { $0.id == viewModel.selectedPackId })?.name ?? "Icon Pack"
    }
    
    private var filteredIcons: [IconItem] {
        var results: [IconItem] = []
        let packsToSearch = viewModel.selectedPackId == "all" ? packManager.installedPacks : packManager.installedPacks.filter { $0.id == viewModel.selectedPackId }
        
        for pack in packsToSearch {
            for cat in pack.categories {
                if viewModel.selectedCategory != "all" && !cat.name.localizedCaseInsensitiveContains(viewModel.selectedCategory) {
                    continue
                }
                results.append(contentsOf: cat.icons)
            }
        }
        
        if !viewModel.searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchText) }
        }
        return results
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
    
    private func pickCustomImageFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .icns, .jpeg]
        panel.prompt = "Choose Icon"
        
        if panel.runModal() == .OK, let url = panel.url {
            onSelectFile(url)
            dismiss()
        }
    }
}

public struct IconGridCell: View {
    public let iconItem: IconItem
    public let onSelect: () -> Void
    @ObservedObject var packManager = IconPackManager.shared
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                if let img = iconItem.image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TidyTheme.roseLight)
                        .frame(width: 52, height: 52)
                }
                
                Text(iconItem.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TidyTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(TidyTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
