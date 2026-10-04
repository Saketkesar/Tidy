import Foundation
import SwiftUI

public enum DownloadState: String, Codable, CaseIterable {
    case queued = "Queued"
    case probing = "Probing"
    case downloading = "Downloading"
    case paused = "Paused"
    case verifying = "Verifying"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public enum SegmentState: String, Codable {
    case pending
    case downloading
    case completed
    case failed
}

public struct DownloadSegment: Identifiable, Codable, Equatable {
    public let id: UUID
    public let index: Int
    public let startOffset: Int64
    public let endOffset: Int64
    public var downloadedBytes: Int64
    public var state: SegmentState
    
    public init(id: UUID = UUID(), index: Int, startOffset: Int64, endOffset: Int64, downloadedBytes: Int64 = 0, state: SegmentState = .pending) {
        self.id = id
        self.index = index
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.downloadedBytes = downloadedBytes
        self.state = state
    }
    
    public var totalBytes: Int64 {
        max(1, endOffset - startOffset + 1)
    }
    
    public var progress: Double {
        min(1.0, Double(downloadedBytes) / Double(totalBytes))
    }
}

public struct DownloadItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let url: URL
    public var finalURL: URL?
    public var fileName: String
    public var destinationFolder: String
    public var category: String
    public var totalBytes: Int64?
    public var downloadedBytes: Int64
    public var state: DownloadState
    public var errorMessage: String?
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var connections: Int
    public var speedLimit: Int64?
    public var currentSpeed: Double // bytes per second
    public var speedSamples: [Double]
    public var etaSeconds: Double?
    public var resumable: Bool
    public var etag: String?
    public var lastModified: String?
    public var segments: [DownloadSegment]
    public var finalFilePath: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        finalURL: URL? = nil,
        fileName: String,
        destinationFolder: String,
        category: String = "Other",
        totalBytes: Int64? = nil,
        downloadedBytes: Int64 = 0,
        state: DownloadState = .queued,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        connections: Int = 8,
        speedLimit: Int64? = nil,
        currentSpeed: Double = 0.0,
        speedSamples: [Double] = [],
        etaSeconds: Double? = nil,
        resumable: Bool = true,
        etag: String? = nil,
        lastModified: String? = nil,
        segments: [DownloadSegment] = [],
        finalFilePath: String? = nil
    ) {
        self.id = id
        self.url = url
        self.finalURL = finalURL
        self.fileName = fileName
        self.destinationFolder = destinationFolder
        self.category = category
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.state = state
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.connections = connections
        self.speedLimit = speedLimit
        self.currentSpeed = currentSpeed
        self.speedSamples = speedSamples
        self.etaSeconds = etaSeconds
        self.resumable = resumable
        self.etag = etag
        self.lastModified = lastModified
        self.segments = segments
        self.finalFilePath = finalFilePath
    }
    
    public var progress: Double {
        guard let total = totalBytes, total > 0 else { return 0.0 }
        return min(1.0, Double(downloadedBytes) / Double(total))
    }
    
    public var percentageString: String {
        guard let total = totalBytes, total > 0 else {
            return downloadedBytes > 0 ? "\(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file))" : "--"
        }
        let pct = Int((Double(downloadedBytes) / Double(total)) * 100)
        return "\(pct)%"
    }
    
    public var formattedSpeed: String {
        guard currentSpeed > 0 else { return "--/s" }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(currentSpeed), countStyle: .file))/s"
    }
    
    public var formattedETA: String {
        guard let eta = etaSeconds, eta > 0, currentSpeed > 0 else { return "--" }
        let totalSecs = Int(eta)
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        if mins > 60 {
            let hours = mins / 60
            return "\(hours)h \(mins % 60)m"
        } else if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    public var formattedSizeProgress: String {
        let doneStr = ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
        if let total = totalBytes, total > 0 {
            let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return "\(doneStr) of \(totalStr)"
        }
        return doneStr
    }
    
    public var host: String {
        url.host ?? "web"
    }
    
    public var isActive: Bool {
        state == .downloading || state == .probing || state == .verifying
    }
    
    public var isQueued: Bool {
        state == .queued
    }
    
    public var isCompleted: Bool {
        state == .completed
    }
    
    public var isFailed: Bool {
        state == .failed
    }
    
    public var isPaused: Bool {
        state == .paused
    }
}

public struct ProbeResult: Equatable {
    public let url: URL
    public let finalURL: URL
    public let fileName: String
    public let totalBytes: Int64?
    public let resumable: Bool
    public let etag: String?
    public let lastModified: String?
    public let contentType: String?
    public let category: String
}
