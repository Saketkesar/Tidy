import Foundation

@MainActor
public class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    @Published public var settings: AppSettings
    @Published public var rules: [OrganizerRule] = []
    @Published public var history: [CleanHistoryEntry] = []
    
    private let appSupportURL: URL
    private let settingsFileURL: URL
    private let rulesFileURL: URL
    private let historyFileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Tidy", isDirectory: true)
        self.appSupportURL = appSupport
        self.settingsFileURL = appSupport.appendingPathComponent("settings.json")
        self.rulesFileURL = appSupport.appendingPathComponent("rules.json")
        self.historyFileURL = appSupport.appendingPathComponent("history.json")
        
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        } catch {
            print("Failed to create app support directory: \(error)")
        }
        
        // 1. Load Settings
        if let data = try? Data(contentsOf: settingsFileURL),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = loaded
        } else {
            self.settings = AppSettings()
        }
        
        // 2. Load Rules or defaults
        if let data = try? Data(contentsOf: rulesFileURL),
           let loaded = try? JSONDecoder().decode([OrganizerRule].self, from: data), !loaded.isEmpty {
            self.rules = loaded.sorted { $0.order < $1.order }
        } else {
            self.rules = Self.defaultOrganizerRules()
            saveRules()
        }
        
        // 3. Load History
        if let data = try? Data(contentsOf: historyFileURL),
           let loaded = try? JSONDecoder().decode([CleanHistoryEntry].self, from: data) {
            self.history = loaded.sorted { $0.timestamp > $1.timestamp }
        } else {
            self.history = []
        }
        
        SafetyManager.shared.setCustomProtectedPaths(self.settings.userProtectedPaths)
    }
    
    public static func defaultOrganizerRules() -> [OrganizerRule] {
        [
            OrganizerRule(name: "Images", isEnabled: true, matchType: .extensions, matchValue: "jpg jpeg png gif heic webp svg", destinationSubfolder: "Images", order: 1),
            OrganizerRule(name: "Documents", isEnabled: true, matchType: .extensions, matchValue: "pdf doc docx txt rtf pages md", destinationSubfolder: "Docs", order: 2),
            OrganizerRule(name: "Sheets", isEnabled: true, matchType: .extensions, matchValue: "xls xlsx csv numbers", destinationSubfolder: "Sheets", order: 3),
            OrganizerRule(name: "Slides", isEnabled: true, matchType: .extensions, matchValue: "ppt pptx key", destinationSubfolder: "Slides", order: 4),
            OrganizerRule(name: "Archives", isEnabled: true, matchType: .extensions, matchValue: "zip rar 7z tar gz", destinationSubfolder: "Archives", order: 5),
            OrganizerRule(name: "Installers", isEnabled: true, matchType: .extensions, matchValue: "dmg pkg", destinationSubfolder: "Install", order: 6),
            OrganizerRule(name: "Video", isEnabled: true, matchType: .extensions, matchValue: "mp4 mov mkv avi", destinationSubfolder: "Video", order: 7),
            OrganizerRule(name: "Audio", isEnabled: true, matchType: .extensions, matchValue: "mp3 wav m4a flac", destinationSubfolder: "Audio", order: 8),
            OrganizerRule(name: "Code", isEnabled: true, matchType: .extensions, matchValue: "py js ts swift c cpp java json", destinationSubfolder: "Code", order: 9),
            OrganizerRule(name: "Everything else", isEnabled: false, matchType: .everythingElse, matchValue: "*", destinationSubfolder: "Other", order: 10)
        ]
    }
    
    public func saveSettings() {
        SafetyManager.shared.setCustomProtectedPaths(settings.userProtectedPaths)
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    public func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            try data.write(to: rulesFileURL, options: .atomic)
        } catch {
            print("Failed to save rules: \(error)")
        }
    }
    
    public func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    public func addHistoryEntry(_ entry: CleanHistoryEntry) {
        history.insert(entry, at: 0)
        settings.lastCleanDate = entry.timestamp
        settings.lastCleanBytesFreed = entry.bytesFreed
        saveSettings()
        saveHistory()
    }
    
    public func markHistoryEntryUndone(id: UUID) {
        if let idx = history.firstIndex(where: { $0.id == id }) {
            history[idx].isUndone = true
            for rIdx in history[idx].records.indices {
                history[idx].records[rIdx].isRestored = true
                history[idx].records[rIdx].statusDescription = "Restored"
            }
            saveHistory()
        }
    }
    
    public func exportHistoryJSON() -> String {
        if let data = try? JSONEncoder().encode(history),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }
    
    public func resetAllSettings() {
        settings = AppSettings()
        rules = Self.defaultOrganizerRules()
        saveSettings()
        saveRules()
    }
}
