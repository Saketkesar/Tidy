import Foundation
import UserNotifications

@MainActor
public final class DownloadsWatcher: ObservableObject {
    public static let shared = DownloadsWatcher()
    
    @Published public private(set) var isWatching: Bool = false
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceTimer: Timer?
    
    private init() {}
    
    public func startWatching(path: String) {
        stopWatching()
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return
        }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open file descriptor for path: \(path)")
            return
        }
        
        let queue = DispatchQueue(label: "com.tidy.watcher.queue", qos: .utility)
        let fsSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .link],
            queue: queue
        )
        
        fsSource.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.handleDirectoryChanged()
            }
        }
        
        fsSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        
        self.source = fsSource
        fsSource.resume()
        self.isWatching = true
    }
    
    public func stopWatching() {
        if let s = source {
            s.cancel()
            source = nil
        }
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        debounceTimer?.invalidate()
        debounceTimer = nil
        isWatching = false
    }
    
    private func handleDirectoryChanged() {
        guard StorageManager.shared.settings.autoOrganizeDownloads else { return }
        
        // Debounce: wait 3 seconds after filesystem events stop
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutoOrganize()
            }
        }
    }
    
    private func performAutoOrganize() async {
        let storage = StorageManager.shared
        guard storage.settings.autoOrganizeDownloads else { return }
        
        let watchedDir = URL(fileURLWithPath: storage.settings.downloadsWatchedPath)
        let destinationRoot = URL(fileURLWithPath: storage.settings.downloadsDestinationPath)
        
        let planner = DownloadsOrganizerPlanner()
        let plan = planner.createPlan(
            sourceDirectory: watchedDir,
            destinationRoot: destinationRoot,
            rules: storage.rules,
            minAgeDays: storage.settings.organizeMinAgeDays,
            groupByMonth: storage.settings.groupByMonth
        )
        
        guard !plan.moves.isEmpty else { return }
        
        let result = planner.executePlan(plan)
        
        // Notification
        if storage.settings.notifyOrganizerActivity && result.movedCount > 0 {
            sendNotification(
                title: "Tidy Organized Downloads",
                body: "Moved \(result.movedCount) \(result.movedCount == 1 ? "file" : "files") to \(destinationRoot.lastPathComponent)."
            )
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}
