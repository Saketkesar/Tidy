import SwiftUI
import AppKit

public struct TidyIcon: View {
    public let name: String
    public let size: CGFloat
    public let sfFallback: String
    
    // In-memory cache for ultra-fast, smooth rendering without disk hitches
    private static var iconCache: [String: NSImage] = [:]
    
    public init(_ name: String, size: CGFloat = 24, sfFallback: String = "circle.fill") {
        self.name = name
        self.size = size
        self.sfFallback = sfFallback
    }
    
    public var body: some View {
        if let image = Self.getOrLoadIcon(name: name) {
            Image(nsImage: image)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: sfFallback)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(TidyTheme.primaryRose)
        }
    }
    
    private static func getOrLoadIcon(name: String) -> NSImage? {
        let cleanName = name.replacingOccurrences(of: ".png", with: "").replacingOccurrences(of: ".svg", with: "")
        if let cached = iconCache[cleanName] {
            return cached
        }
        
        if let loaded = loadIconImage(cleanName: cleanName) {
            loaded.isTemplate = false
            iconCache[cleanName] = loaded
            return loaded
        }
        return nil
    }
    
    private static func loadIconImage(cleanName: String) -> NSImage? {
        // 1. Direct workspace full-color 32-bit RGBA PNGs
        let searchPaths = [
            "/Users/saketkesar/Downloads/dinly/Tidy/Resources/icons/\(cleanName).png",
            "/Users/saketkesar/Downloads/dinly/Tidy/Resources/download-icons/\(cleanName).png",
            "./Resources/icons/\(cleanName).png",
            "./Resources/download-icons/\(cleanName).png",
            "../Resources/icons/\(cleanName).png",
            "../Resources/download-icons/\(cleanName).png"
        ]
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
                img.isTemplate = false
                return img
            }
        }
        
        // 2. Check app bundle Contents/Resources/icons/
        if let resURL = Bundle.main.resourceURL {
            let bundleIconURL = resURL.appendingPathComponent("icons/\(cleanName).png")
            if FileManager.default.fileExists(atPath: bundleIconURL.path), let img = NSImage(contentsOf: bundleIconURL) {
                img.isTemplate = false
                return img
            }
            
            let directBundleURL = resURL.appendingPathComponent("\(cleanName).png")
            if FileManager.default.fileExists(atPath: directBundleURL.path), let img = NSImage(contentsOf: directBundleURL) {
                img.isTemplate = false
                return img
            }
        }
        
        // 3. Check Bundle url(forResource:withExtension:)
        if let url = Bundle.main.url(forResource: cleanName, withExtension: "png", subdirectory: "icons") ??
                     Bundle.main.url(forResource: cleanName, withExtension: "png") {
            if let img = NSImage(contentsOf: url) {
                img.isTemplate = false
                return img
            }
        }
        
        // 4. Raw SVGs from tidy-icons or Resources/svg
        let svgPaths = [
            "/Users/saketkesar/Downloads/dinly/Tidy/tidy-icons/\(cleanName).svg",
            "/Users/saketkesar/Downloads/dinly/Tidy/Resources/svg/\(cleanName).svg"
        ]
        for path in svgPaths {
            if FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
                img.isTemplate = false
                return img
            }
        }
        
        return nil
    }
}
