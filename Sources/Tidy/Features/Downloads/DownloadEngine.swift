import Foundation
import SwiftUI
import AppKit
import Darwin

@MainActor
public final class DownloadEngine: ObservableObject {
    public static let shared = DownloadEngine()
    
    @Published public var downloads: [DownloadItem] = []
    @Published public var totalSpeed: Double = 0.0
    @Published public var activeCount: Int = 0
    
    private let stateFileURL: URL
    private var activeTasks: [UUID: [URLSessionDataTask]] = [:]
    private var fileHandles: [UUID: FileHandle] = [:]
    private var speedTimer: Timer?
    private var speedByteCounters: [UUID: Int64] = [:]
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Tidy", isDirectory: true)
        self.stateFileURL = appSupport.appendingPathComponent("downloads_state.json")
        
        loadPersistedDownloads()
        startSpeedMonitor()
    }
    
    deinit {
        speedTimer?.invalidate()
    }
    
    // MARK: - Probe Phase (HEAD or Range GET)
    public func probeURL(_ url: URL) async throws -> ProbeResult {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession(configuration: .default)
        var response: URLResponse
        var totalBytes: Int64? = nil
        var resumable: Bool = false
        var finalURL: URL = url
        var etag: String? = nil
        var lastModified: String? = nil
        var contentType: String? = nil
        var fileName: String = url.lastPathComponent
        
        do {
            let (_, resp) = try await session.data(for: request)
            response = resp
        } catch {
            // Fall back to GET with Range: bytes=0-0
            var getReq = URLRequest(url: url)
            getReq.httpMethod = "GET"
            getReq.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            let (_, resp) = try await session.data(for: getReq)
            response = resp
        }
        
        if let http = response as? HTTPURLResponse {
            if let resolved = http.url {
                finalURL = resolved
            }
            etag = http.value(forHTTPHeaderField: "ETag")
            lastModified = http.value(forHTTPHeaderField: "Last-Modified")
            contentType = http.value(forHTTPHeaderField: "Content-Type")
            
            if let acceptRanges = http.value(forHTTPHeaderField: "Accept-Ranges"), acceptRanges.lowercased().contains("bytes") {
                resumable = true
            } else if http.statusCode == 206 {
                resumable = true
            }
            
            if let lengthStr = http.value(forHTTPHeaderField: "Content-Length"), let len = Int64(lengthStr) {
                totalBytes = len
            } else if let rangeStr = http.value(forHTTPHeaderField: "Content-Range"), let totalStr = rangeStr.components(separatedBy: "/").last, let len = Int64(totalStr) {
                totalBytes = len
            }
            
            // Filename from Content-Disposition
            if let disposition = http.value(forHTTPHeaderField: "Content-Disposition") {
                if let parsed = extractFilename(from: disposition) {
                    fileName = parsed
                }
            }
        }
        
        // Sanitize filename (R5)
        fileName = sanitizeFileName(fileName.isEmpty ? finalURL.lastPathComponent : fileName)
        if fileName.isEmpty {
            fileName = "download-\(Int(Date().timeIntervalSince1970))"
        }
        
        let category = determineCategory(for: fileName)
        
        return ProbeResult(
            url: url,
            finalURL: finalURL,
            fileName: fileName,
            totalBytes: totalBytes,
            resumable: resumable,
            etag: etag,
            lastModified: lastModified,
            contentType: contentType,
            category: category
        )
    }
    
    // MARK: - Start / Add Download
    public func addDownload(
        url: URL,
        probe: ProbeResult,
        destinationFolder: String,
        category: String,
        connections: Int = 8,
        startImmediately: Bool = true
    ) -> DownloadItem {
        let initialSegments: [DownloadSegment]
        let total = probe.totalBytes ?? 0
        let connCount = (probe.resumable && total > 2 * 1024 * 1024) ? min(connections, max(1, Int(total / (1024 * 1024)))) : 1
        
        if connCount > 1, total > 0 {
            var segs: [DownloadSegment] = []
            let chunkSize = total / Int64(connCount)
            for i in 0..<connCount {
                let start = Int64(i) * chunkSize
                let end = (i == connCount - 1) ? (total - 1) : (start + chunkSize - 1)
                segs.append(DownloadSegment(index: i, startOffset: start, endOffset: end, downloadedBytes: 0, state: .pending))
            }
            initialSegments = segs
        } else {
            initialSegments = [DownloadSegment(index: 0, startOffset: 0, endOffset: max(0, total - 1), downloadedBytes: 0, state: .pending)]
        }
        
        let item = DownloadItem(
            url: url,
            finalURL: probe.finalURL,
            fileName: probe.fileName,
            destinationFolder: destinationFolder,
            category: category,
            totalBytes: probe.totalBytes,
            downloadedBytes: 0,
            state: .queued,
            createdAt: Date(),
            connections: connCount,
            resumable: probe.resumable,
            etag: probe.etag,
            lastModified: probe.lastModified,
            segments: initialSegments
        )
        
        downloads.insert(item, at: 0)
        persistDownloads()
        
        if startImmediately {
            startDownload(id: item.id)
        }
        return item
    }
    
    public func startDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].state = .downloading
        downloads[idx].startedAt = Date()
        persistDownloads()
        updateActiveCount()
        
        let item = downloads[idx]
        executeDownload(item: item)
    }
    
    public func pauseDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        if let tasks = activeTasks[id] {
            tasks.forEach { $0.cancel() }
            activeTasks.removeValue(forKey: id)
        }
        if let handle = fileHandles[id] {
            try? handle.synchronize()
            try? handle.close()
            fileHandles.removeValue(forKey: id)
        }
        downloads[idx].state = .paused
        downloads[idx].currentSpeed = 0
        persistDownloads()
        updateActiveCount()
    }
    
    public func resumeDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].state = .downloading
        persistDownloads()
        updateActiveCount()
        
        let item = downloads[idx]
        executeDownload(item: item)
    }
    
    public func cancelDownload(id: UUID) {
        pauseDownload(id: id)
        if let idx = downloads.firstIndex(where: { $0.id == id }) {
            downloads[idx].state = .cancelled
            // Clean up partial file
            let partPath = URL(fileURLWithPath: downloads[idx].destinationFolder).appendingPathComponent("\(downloads[idx].fileName).tidypart").path
            try? FileManager.default.removeItem(atPath: partPath)
            persistDownloads()
        }
        updateActiveCount()
    }
    
    public func retryDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].errorMessage = nil
        downloads[idx].downloadedBytes = 0
        for sIdx in downloads[idx].segments.indices {
            downloads[idx].segments[sIdx].downloadedBytes = 0
            downloads[idx].segments[sIdx].state = .pending
        }
        startDownload(id: id)
    }
    
    public func removeDownload(id: UUID, deleteFile: Bool = false) {
        if let idx = downloads.firstIndex(where: { $0.id == id }) {
            let item = downloads[idx]
            pauseDownload(id: id)
            if deleteFile {
                if let final = item.finalFilePath {
                    _ = try? FileManager.default.trashItem(at: URL(fileURLWithPath: final), resultingItemURL: nil)
                }
                let partPath = URL(fileURLWithPath: item.destinationFolder).appendingPathComponent("\(item.fileName).tidypart").path
                try? FileManager.default.removeItem(atPath: partPath)
            }
            downloads.remove(at: idx)
            persistDownloads()
        }
        updateActiveCount()
    }
    
    public func pauseAll() {
        for d in downloads where d.isActive {
            pauseDownload(id: d.id)
        }
    }
    
    public func resumeAll() {
        for d in downloads where d.state == .paused {
            resumeDownload(id: d.id)
        }
    }
    
    // MARK: - Segment Execution Engine
    private func executeDownload(item: DownloadItem) {
        let destURL = URL(fileURLWithPath: item.destinationFolder)
        let fm = FileManager.default
        try? fm.createDirectory(at: destURL, withIntermediateDirectories: true)
        
        let partFile = destURL.appendingPathComponent("\(item.fileName).tidypart")
        
        // 1. Pre-allocate file if needed
        if !fm.fileExists(atPath: partFile.path) {
            fm.createFile(atPath: partFile.path, contents: nil)
            if let total = item.totalBytes, total > 0, let fh = try? FileHandle(forWritingTo: partFile) {
                try? fh.truncate(atOffset: UInt64(total))
                try? fh.close()
            }
        }
        
        guard let masterHandle = try? FileHandle(forWritingTo: partFile) else {
            markDownloadFailed(id: item.id, reason: "Could not create destination file handle")
            return
        }
        fileHandles[item.id] = masterHandle
        
        let session = URLSession(configuration: .default)
        var runningTasks: [URLSessionDataTask] = []
        let downloadId = item.id
        
        for segment in item.segments {
            if segment.downloadedBytes >= segment.totalBytes && segment.totalBytes > 0 {
                continue
            }
            
            let segStart = segment.startOffset + segment.downloadedBytes
            let segEnd = segment.endOffset
            
            var req = URLRequest(url: item.finalURL ?? item.url)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
            
            if item.resumable && segEnd > segStart {
                req.setValue("bytes=\(segStart)-\(segEnd)", forHTTPHeaderField: "Range")
                if let etag = item.etag {
                    req.setValue(etag, forHTTPHeaderField: "If-Range")
                }
            }
            
            let segIndex = segment.index
            let task = session.dataTask(with: req) { [weak self] data, response, error in
                guard let self = self else { return }
                if let error = error as NSError?, error.code == NSURLErrorCancelled {
                    return
                }
                
                if let error = error {
                    Task { @MainActor in
                        self.markDownloadFailed(id: downloadId, reason: error.localizedDescription)
                    }
                    return
                }
                
                if let data = data {
                    // Write at exact offset using pwrite for parallel safety
                    let writeOffset = off_t(segStart)
                    let fd = masterHandle.fileDescriptor
                    _ = data.withUnsafeBytes { ptr in
                        pwrite(fd, ptr.baseAddress, data.count, writeOffset)
                    }
                    
                    Task { @MainActor in
                        self.recordBytes(downloadId: downloadId, segmentIndex: segIndex, bytesCount: Int64(data.count))
                    }
                }
            }
            
            runningTasks.append(task)
            task.resume()
        }
        
        activeTasks[downloadId] = runningTasks
    }
    
    private func recordBytes(downloadId: UUID, segmentIndex: Int, bytesCount: Int64) {
        guard let idx = downloads.firstIndex(where: { $0.id == downloadId }) else { return }
        downloads[idx].downloadedBytes += bytesCount
        if segmentIndex < downloads[idx].segments.count {
            downloads[idx].segments[segmentIndex].downloadedBytes += bytesCount
            if downloads[idx].segments[segmentIndex].downloadedBytes >= downloads[idx].segments[segmentIndex].totalBytes {
                downloads[idx].segments[segmentIndex].state = .completed
            } else {
                downloads[idx].segments[segmentIndex].state = .downloading
            }
        }
        speedByteCounters[downloadId, default: 0] += bytesCount
        
        // Check if finished
        let total = downloads[idx].totalBytes ?? 0
        if (total > 0 && downloads[idx].downloadedBytes >= total) || downloads[idx].segments.allSatisfy({ $0.state == .completed }) {
            completeDownload(id: downloadId)
        }
    }
    
    private func completeDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        
        // Close handles
        if let handle = fileHandles[id] {
            try? handle.synchronize()
            try? handle.close()
            fileHandles.removeValue(forKey: id)
        }
        activeTasks.removeValue(forKey: id)
        
        let item = downloads[idx]
        let destURL = URL(fileURLWithPath: item.destinationFolder)
        let partFile = destURL.appendingPathComponent("\(item.fileName).tidypart")
        
        // Resolve name collision (R5)
        var finalName = item.fileName
        var finalURL = destURL.appendingPathComponent(finalName)
        var counter = 2
        let nameWithoutExt = (item.fileName as NSString).deletingPathExtension
        let ext = (item.fileName as NSString).pathExtension
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            if ext.isEmpty {
                finalName = "\(nameWithoutExt) (\(counter))"
            } else {
                finalName = "\(nameWithoutExt) (\(counter)).\(ext)"
            }
            finalURL = destURL.appendingPathComponent(finalName)
            counter += 1
        }
        
        try? FileManager.default.moveItem(at: partFile, to: finalURL)
        
        // Set macOS Quarantine attribute (R4)
        applyQuarantineAttribute(to: finalURL.path)
        
        // Auto-sort into Downloads/Sorted/<Category> if enabled
        var resultingPath = finalURL.path
        let storage = StorageManager.shared
        if storage.settings.autoOrganizeDownloads {
            let sortedRoot = URL(fileURLWithPath: storage.settings.downloadsDestinationPath)
            let catDir = sortedRoot.appendingPathComponent(item.category)
            try? FileManager.default.createDirectory(at: catDir, withIntermediateDirectories: true)
            let sortedTarget = catDir.appendingPathComponent(finalName)
            if (try? FileManager.default.moveItem(at: finalURL, to: sortedTarget)) != nil {
                resultingPath = sortedTarget.path
            }
        }
        
        downloads[idx].state = .completed
        downloads[idx].completedAt = Date()
        downloads[idx].finalFilePath = resultingPath
        downloads[idx].currentSpeed = 0
        downloads[idx].etaSeconds = 0
        
        // Record in Tidy History
        let record = HistoryItemRecord(
            originalPath: item.url.absoluteString,
            movedDestinationPath: resultingPath,
            sizeBytes: item.downloadedBytes,
            itemName: finalName,
            statusDescription: "Downloaded & Saved"
        )
        let histEntry = CleanHistoryEntry(
            actionType: .downloadsOrganized,
            title: "Downloaded \(finalName)",
            bytesFreed: 0,
            itemsCount: 1,
            records: [record]
        )
        storage.history.insert(histEntry, at: 0)
        storage.saveHistory()
        
        persistDownloads()
        updateActiveCount()
        
        // Send notification
        postDownloadNotification(fileName: finalName, path: resultingPath)
    }
    
    private func markDownloadFailed(id: UUID, reason: String) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].state = .failed
        downloads[idx].errorMessage = reason
        downloads[idx].currentSpeed = 0
        downloads[idx].etaSeconds = nil
        if let handle = fileHandles[id] {
            try? handle.close()
            fileHandles.removeValue(forKey: id)
        }
        activeTasks.removeValue(forKey: id)
        persistDownloads()
        updateActiveCount()
    }
    
    // MARK: - Speed Rolling Monitor (R2)
    private func startSpeedMonitor() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.calculateRollingSpeeds()
            }
        }
    }
    
    private func calculateRollingSpeeds() {
        var total: Double = 0.0
        for i in downloads.indices {
            let id = downloads[i].id
            if downloads[i].isActive {
                let bytesInSecond = Double(speedByteCounters[id, default: 0])
                speedByteCounters[id] = 0
                
                // Rolling speed calculation
                let speed = bytesInSecond
                downloads[i].currentSpeed = speed
                total += speed
                
                downloads[i].speedSamples.append(speed)
                if downloads[i].speedSamples.count > 30 {
                    downloads[i].speedSamples.removeFirst()
                }
                
                if let totalBytes = downloads[i].totalBytes, speed > 0 {
                    let remaining = max(0, totalBytes - downloads[i].downloadedBytes)
                    downloads[i].etaSeconds = Double(remaining) / speed
                } else {
                    downloads[i].etaSeconds = nil
                }
            } else {
                downloads[i].currentSpeed = 0
                downloads[i].etaSeconds = nil
            }
        }
        self.totalSpeed = total
    }
    
    private func updateActiveCount() {
        self.activeCount = downloads.filter { $0.isActive }.count
    }
    
    // MARK: - Helpers & Sanitization
    private func sanitizeFileName(_ name: String) -> String {
        var clean = name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "..", with: "")
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix(".") {
            clean = "file" + clean
        }
        return clean
    }
    
    private func extractFilename(from disposition: String) -> String? {
        // e.g. attachment; filename="example.zip" or filename*=UTF-8''example.zip
        if let range = disposition.range(of: "filename\\*?=['\"]?([^'\";]+)['\"]?", options: .regularExpression) {
            let match = String(disposition[range])
            let parts = match.components(separatedBy: "=")
            if parts.count > 1 {
                return parts[1].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
            }
        }
        return nil
    }
    
    private func determineCategory(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "svg": return "Images"
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "md": return "Docs"
        case "xls", "xlsx", "csv", "numbers": return "Sheets"
        case "ppt", "pptx", "key": return "Slides"
        case "zip", "rar", "7z", "tar", "gz": return "Archives"
        case "dmg", "pkg": return "Install"
        case "mp4", "mov", "mkv", "avi": return "Video"
        case "mp3", "wav", "m4a", "flac": return "Audio"
        case "py", "js", "ts", "swift", "c", "cpp", "java", "json": return "Code"
        default: return "Other"
        }
    }
    
    private func applyQuarantineAttribute(to filePath: String) {
        let key = "com.apple.quarantine"
        let val = "0081;00000000;Tidy;0"
        setxattr(filePath, key, val, val.utf8.count, 0, 0)
    }
    
    private func postDownloadNotification(fileName: String, path: String) {
        let notification = NSUserNotification()
        notification.title = "Download Complete"
        notification.informativeText = "\(fileName) finished downloading."
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Persistence
    private func loadPersistedDownloads() {
        if let data = try? Data(contentsOf: stateFileURL),
           let loaded = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            // Per R7.3: Mark downloading/probing items as paused on launch
            self.downloads = loaded.map { item in
                var mod = item
                if mod.state == .downloading || mod.state == .probing {
                    mod.state = .paused
                }
                mod.currentSpeed = 0
                mod.etaSeconds = nil
                return mod
            }
        } else {
            self.downloads = []
        }
        updateActiveCount()
    }
    
    private func persistDownloads() {
        do {
            let data = try JSONEncoder().encode(downloads)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            print("Failed to persist downloads: \(error)")
        }
    }
}
