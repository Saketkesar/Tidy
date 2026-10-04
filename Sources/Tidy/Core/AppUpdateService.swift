import Foundation
import AppKit
import SwiftUI

public struct GitHubAsset: Codable {
    public let name: String
    public let browser_download_url: String
    public let size: Int64?
}

public struct GitHubRelease: Codable {
    public let tag_name: String
    public let name: String?
    public let body: String?
    public let html_url: String
    public let published_at: String?
    public let assets: [GitHubAsset]?
}

@MainActor
public final class AppUpdateService: ObservableObject {
    public static let shared = AppUpdateService()
    
    public let currentVersion = "1.2.0"
    public let githubRepoURL = URL(string: "https://github.com/Saketkesar/Tidy")!
    public let githubProfileURL = URL(string: "https://github.com/Saketkesar")!
    public let developerEmail = "saketkesar391@gmail.com"
    public let developerName = "Saket Kesar"
    
    @Published public var isChecking: Bool = false
    @Published public var isDownloading: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestRelease: GitHubRelease? = nil
    @Published public var statusMessage: String? = nil
    @Published public var downloadProgress: Double = 0.0
    
    private init() {
        if StorageManager.shared.settings.autoCheckUpdates {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await checkForUpdates(manual: false)
            }
        }
    }
    
    public func checkForUpdates(manual: Bool = true) async {
        isChecking = true
        if manual {
            statusMessage = "Checking for updates..."
        }
        
        let endpoint = URL(string: "https://api.github.com/repos/Saketkesar/Tidy/releases/latest")!
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Tidy-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                if manual { statusMessage = "Could not check updates" }
                isChecking = false
                return
            }
            
            if http.statusCode == 200 {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                self.latestRelease = release
                
                let remoteVer = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if isVersion(remoteVer, greaterThan: currentVersion) {
                    self.updateAvailable = true
                    self.statusMessage = "Update available: v\(remoteVer) 🎉"
                } else {
                    self.updateAvailable = false
                    if manual {
                        self.statusMessage = "Tidy v\(currentVersion) is up to date ✨"
                    }
                }
            } else if http.statusCode == 404 {
                self.updateAvailable = false
                if manual {
                    self.statusMessage = "Tidy v\(currentVersion) is the latest release."
                }
            } else {
                if manual {
                    self.statusMessage = "GitHub API response: \(http.statusCode)"
                }
            }
        } catch {
            if manual {
                self.statusMessage = "Update check error: \(error.localizedDescription)"
            }
        }
        isChecking = false
    }
    
    public func openReleasePage() {
        if let rel = latestRelease, let url = URL(string: rel.html_url) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(githubRepoURL.appendingPathComponent("releases"))
        }
    }
    
    public func downloadAndInstallUpdate() {
        guard let rel = latestRelease else {
            openReleasePage()
            return
        }
        
        // Find .dmg or .zip asset
        if let asset = rel.assets?.first(where: { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }),
           let downloadURL = URL(string: asset.browser_download_url) {
            
            isDownloading = true
            statusMessage = "Downloading \(asset.name)..."
            
            let destURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads")
                .appendingPathComponent(asset.name)
            
            Task {
                do {
                    let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    
                    self.isDownloading = false
                    self.statusMessage = "Downloaded! Opening installer..."
                    
                    NSWorkspace.shared.open(destURL)
                } catch {
                    self.isDownloading = false
                    self.statusMessage = "Download failed, opening browser instead..."
                    self.openReleasePage()
                }
            }
        } else {
            openReleasePage()
        }
    }
    
    public func openReportBug() {
        let url = URL(string: "https://github.com/Saketkesar/Tidy/issues/new?title=%5BBug%5D+&labels=bug")!
        NSWorkspace.shared.open(url)
    }
    
    public func openSuggestFeature() {
        let url = URL(string: "https://github.com/Saketkesar/Tidy/issues/new?title=%5BFeature+Request%5D+&labels=enhancement")!
        NSWorkspace.shared.open(url)
    }
    
    public func openContribute() {
        NSWorkspace.shared.open(githubRepoURL)
    }
    
    public func openDeveloperGitHub() {
        NSWorkspace.shared.open(githubProfileURL)
    }
    
    public func contactDeveloperEmail() {
        if let mailto = URL(string: "mailto:\(developerEmail)?subject=Tidy%20for%20macOS%20Feedback") {
            NSWorkspace.shared.open(mailto)
        }
    }
    
    private func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let parts1 = v1.components(separatedBy: ".").compactMap { Int($0) }
        let parts2 = v2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}
