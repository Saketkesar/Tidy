import Foundation
import AppKit
import SwiftUI

public struct IconItem: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let packName: String
    public let categoryName: String
    public let fileURL: URL
    public let fileType: String
    
    public init(id: UUID = UUID(), name: String, packName: String, categoryName: String, fileURL: URL, fileType: String) {
        self.id = id
        self.name = name
        self.packName = packName
        self.categoryName = categoryName
        self.fileURL = fileURL
        self.fileType = fileType
    }
    
    public var image: NSImage? {
        NSImage(contentsOf: fileURL)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fileURL.path)
    }
    
    public static func == (lhs: IconItem, rhs: IconItem) -> Bool {
        lhs.fileURL.path == rhs.fileURL.path
    }
}

public struct IconPackCategory: Identifiable {
    public var id: String { name }
    public let name: String
    public var icons: [IconItem]
    
    public init(name: String, icons: [IconItem]) {
        self.name = name
        self.icons = icons
    }
}

public struct IconPack: Identifiable {
    public var id: String { name }
    public let name: String
    public let folderURL: URL
    public var categories: [IconPackCategory]
    public var totalIcons: Int {
        categories.reduce(0) { $0 + $1.icons.count }
    }
    
    public init(name: String, folderURL: URL, categories: [IconPackCategory]) {
        self.name = name
        self.folderURL = folderURL
        self.categories = categories
    }
}

@MainActor
public final class IconPackManager: ObservableObject {
    public static let shared = IconPackManager()
    
    @Published public var installedPacks: [IconPack] = []
    @Published public var isImporting: Bool = false
    @Published public var statusMessage: String? = nil
    
    public let wallpapersClanURL = URL(string: "https://wallpapers-clan.com/folder-icons/")!
    private let iconPacksRoot: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Tidy/IconPacks", isDirectory: true)
        self.iconPacksRoot = appSupport
        
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        loadAllPacks()
        
        // Auto-seed bundled or workspace packs on first launch
        autoSeedDefaultPacks()
    }
    
    public func openWallpapersClan() {
        NSWorkspace.shared.open(wallpapersClanURL)
    }
    
    public func refreshPacks() {
        loadAllPacks()
    }
    
    public func loadAllPacks() {
        let fm = FileManager.default
        guard let packDirs = try? fm.contentsOfDirectory(at: iconPacksRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            self.installedPacks = []
            return
        }
        
        var packs: [IconPack] = []
        for packDir in packDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: packDir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if packDir.lastPathComponent.hasPrefix(".") || packDir.lastPathComponent == "__MACOSX" { continue }
            
            if let pack = scanPackDirectory(packDir) {
                packs.append(pack)
            }
        }
        
        self.installedPacks = packs.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    private func scanPackDirectory(_ dir: URL) -> IconPack? {
        let fm = FileManager.default
        let packName = dir.lastPathComponent.replacingOccurrences(of: "-", with: " ").capitalized
        
        var categoryMap: [String: [IconItem]] = [:]
        
        let validExts: Set<String> = ["png", "icns", "ico", "jpg", "jpeg", "webp"]
        
        if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.path.contains("__MACOSX") || fileURL.lastPathComponent.hasPrefix(".") {
                    continue
                }
                
                let ext = fileURL.pathExtension.lowercased()
                guard validExts.contains(ext) else { continue }
                
                // Determine category based on parent folder relative to pack root
                let relativePath = fileURL.path.replacingOccurrences(of: dir.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let components = relativePath.components(separatedBy: "/")
                let catName: String
                if components.count > 1 {
                    catName = components[0]
                } else {
                    catName = "General"
                }
                
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let item = IconItem(
                    name: baseName,
                    packName: packName,
                    categoryName: catName,
                    fileURL: fileURL,
                    fileType: ext
                )
                categoryMap[catName, default: []].append(item)
            }
        }
        
        guard !categoryMap.isEmpty else { return nil }
        
        var categories: [IconPackCategory] = []
        for (catName, items) in categoryMap {
            let sortedItems = items.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            categories.append(IconPackCategory(name: catName, icons: sortedItems))
        }
        categories.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        return IconPack(name: packName, folderURL: dir, categories: categories)
    }
    
    public func importPack(from zipURL: URL) async -> Bool {
        isImporting = true
        statusMessage = "Extracting icon pack..."
        
        let fm = FileManager.default
        let rawBaseName = zipURL.deletingPathExtension().lastPathComponent
        let cleanBaseName = rawBaseName
            .replacingOccurrences(of: "-wallpapers-clan-com", with: "")
            .replacingOccurrences(of: "-MAC", with: "")
            .replacingOccurrences(of: "-folder-icons", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let destinationDir = iconPacksRoot.appendingPathComponent(cleanBaseName, isDirectory: true)
        
        return await Task.detached(priority: .userInitiated) { () -> Bool in
            try? fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", zipURL.path, "-d", destinationDir.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Remove __MACOSX if present
                let macosxDir = destinationDir.appendingPathComponent("__MACOSX")
                try? fm.removeItem(at: macosxDir)
                
                await MainActor.run {
                    self.loadAllPacks()
                    self.isImporting = false
                    self.statusMessage = "Imported '\(cleanBaseName.capitalized)' icon pack!"
                }
                return true
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.statusMessage = "Failed to unzip icon pack: \(error.localizedDescription)"
                }
                return false
            }
        }.value
    }
    
    private func autoSeedDefaultPacks() {
        if installedPacks.isEmpty {
            let candidatePaths: [String] = [
                "/Users/saketkesar/Downloads/dinly/Tidy/my-hero-academia-folder-icons-MAC-wallpapers-clan-com.zip"
            ]
            
            for path in candidatePaths {
                if FileManager.default.fileExists(atPath: path) {
                    Task {
                        _ = await importPack(from: URL(fileURLWithPath: path))
                    }
                    break
                }
            }
        }
    }
    
    // MARK: - Mac-Wide Icon Setter API
    
    public func applyIcon(image: NSImage, to path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: path, isDirectory: &isDir) {
            // If path doesn't exist, check if user is targeting a planned subfolder
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        
        let success = NSWorkspace.shared.setIcon(image, forFile: path, options: [])
        if success {
            self.statusMessage = "Icon applied successfully!"
        } else {
            self.statusMessage = "Failed to set icon for path"
        }
        return success
    }
    
    public func applyIcon(from fileURL: URL, to path: String) -> Bool {
        guard let img = NSImage(contentsOf: fileURL) else {
            self.statusMessage = "Could not load image from \(fileURL.lastPathComponent)"
            return false
        }
        return applyIcon(image: img, to: path)
    }
    
    public func resetIcon(for path: String) -> Bool {
        let success = NSWorkspace.shared.setIcon(nil, forFile: path, options: [])
        if success {
            self.statusMessage = "Restored default icon"
        }
        return success
    }
}
