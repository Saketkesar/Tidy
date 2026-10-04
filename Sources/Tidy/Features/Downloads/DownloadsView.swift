import SwiftUI
import AppKit

public enum DownloadFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case queued = "Queued"
    case completed = "Completed"
    case failed = "Failed"
    
    public var id: String { rawValue }
}

@MainActor
public class DownloadsViewModel: ObservableObject {
    @Published public var filter: DownloadFilter = .all
    @Published public var searchQuery: String = ""
    @Published public var isShowingAddSheet: Bool = false
    
    public init() {}
}

public struct DownloadsView: View {
    @ObservedObject var engine = DownloadEngine.shared
    @ObservedObject var diskInfo = DiskInfoService.shared
    @StateObject private var viewModel = DownloadsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloads")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Multi-connection segmented download manager with real-time chunk visualization.")
                        .font(.system(size: 12.5))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(TidyTheme.textMuted)
                    TextField("Search downloads...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TidyTheme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                )
                .frame(width: 180)
                
                // Pause / Resume All
                Button(action: {
                    if engine.activeCount > 0 {
                        engine.pauseAll()
                    } else {
                        engine.resumeAll()
                    }
                }) {
                    HStack(spacing: 5) {
                        TidyIcon(engine.activeCount > 0 ? "dl-pause" : "dl-resume", size: 14, sfFallback: "pause.fill")
                        Text(engine.activeCount > 0 ? "Pause All" : "Resume All")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(TidyTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(TidyTheme.roseChipBg)
                            .overlay(Capsule().stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(engine.downloads.isEmpty)
                
                // + Add URL Button
                Button(action: {
                    viewModel.isShowingAddSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add URL")
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
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 14)
            
            // Filter Chips Bar
            HStack(spacing: 8) {
                ForEach(DownloadFilter.allCases) { f in
                    let count = countForFilter(f)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.filter = f
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(f.rawValue)
                                .font(.system(size: 12, weight: viewModel.filter == f ? .bold : .medium))
                            
                            Text("\(count)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(viewModel.filter == f ? .white : TidyTheme.primaryRose)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(viewModel.filter == f ? TidyTheme.primaryRose : TidyTheme.roseLight)
                                )
                        }
                        .foregroundColor(viewModel.filter == f ? TidyTheme.primaryRose : TidyTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(viewModel.filter == f ? TidyTheme.roseLight : Color.clear)
                                .overlay(
                                    Capsule()
                                        .stroke(viewModel.filter == f ? TidyTheme.roseSoftBorder : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            
            Divider().opacity(0.4)
            
            // Main Downloads List / Empty State
            let displayedItems = filteredDownloads
            if displayedItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayedItems) { item in
                            DownloadRowView(item: item)
                        }
                    }
                    .padding(28)
                }
            }
            
            Divider().opacity(0.4)
            
            // Bottom Status Bar
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    if engine.activeCount > 0 {
                        AnimatedWebPView("tidy-downloading.webp")
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .fill(TidyTheme.textMuted)
                            .frame(width: 8, height: 8)
                    }
                    Text("\(engine.activeCount) active transfers")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                }
                
                HStack(spacing: 6) {
                    TidyIcon("dl-speed", size: 14, sfFallback: "speedometer")
                    Text("Total speed: \(ByteCountFormatter.string(fromByteCount: Int64(engine.totalSpeed), countStyle: .file))/s")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(TidyTheme.primaryRose)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 11))
                        .foregroundColor(TidyTheme.textSecondary)
                    Text("Disk Free: \(diskInfo.formattedFree)")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(TidyTheme.textSecondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(TidyTheme.cardBackground)
        }
        .background(TidyTheme.windowBackground)
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            AddDownloadSheet()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Authentic Mascot WebP for Downloading
            AnimatedWebPView("tidy-downloading.webp")
                .frame(width: 96, height: 96)
                .shadow(color: TidyTheme.primaryRose.opacity(0.2), radius: 10, y: 3)
            
            VStack(spacing: 4) {
                Text("Nothing downloading")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(TidyTheme.textPrimary)
                
                Text("Paste a URL or drop a link to download with parallel high-speed connections.")
                    .font(.system(size: 12))
                    .foregroundColor(TidyTheme.textSecondary)
            }
            
            Button(action: {
                viewModel.isShowingAddSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Download URL")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(TidyTheme.primaryGradient)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filteredDownloads: [DownloadItem] {
        var list = engine.downloads
        
        switch viewModel.filter {
        case .all:
            break
        case .active:
            list = list.filter { $0.isActive }
        case .queued:
            list = list.filter { $0.isQueued }
        case .completed:
            list = list.filter { $0.isCompleted }
        case .failed:
            list = list.filter { $0.isFailed }
        }
        
        if !viewModel.searchQuery.isEmpty {
            list = list.filter { $0.fileName.localizedCaseInsensitiveContains(viewModel.searchQuery) }
        }
        return list
    }
    
    private func countForFilter(_ f: DownloadFilter) -> Int {
        switch f {
        case .all: return engine.downloads.count
        case .active: return engine.downloads.filter { $0.isActive }.count
        case .queued: return engine.downloads.filter { $0.isQueued }.count
        case .completed: return engine.downloads.filter { $0.isCompleted }.count
        case .failed: return engine.downloads.filter { $0.isFailed }.count
        }
    }
}

public struct DownloadRowView: View {
    public let item: DownloadItem
    @ObservedObject var engine = DownloadEngine.shared
    
    public var body: some View {
        VStack(spacing: 10) {
            // Main Top Row
            HStack(spacing: 12) {
                // Category / File Icon
                TidyIcon(categoryIcon(for: item.category), size: 36, sfFallback: "doc.fill")
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(item.fileName)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(TidyTheme.textPrimary)
                            .lineLimit(1)
                        
                        // Category Chip
                        Text(item.category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(TidyTheme.primaryRose)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(TidyTheme.roseLight))
                    }
                    
                    HStack(spacing: 6) {
                        Text(item.host)
                            .font(.system(size: 11))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        Text("•")
                            .foregroundColor(TidyTheme.textMuted)
                        
                        Text(item.formattedSizeProgress)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        if let err = item.errorMessage {
                            Text("•")
                                .foregroundColor(TidyTheme.textMuted)
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(TidyTheme.dangerColor)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    if item.isActive {
                        Button(action: {
                            engine.pauseDownload(id: item.id)
                        }) {
                            TidyIcon("dl-pause", size: 20, sfFallback: "pause.fill")
                        }
                        .buttonStyle(.plain)
                        .help("Pause download")
                    } else if item.isPaused {
                        Button(action: {
                            engine.resumeDownload(id: item.id)
                        }) {
                            TidyIcon("dl-resume", size: 20, sfFallback: "play.fill")
                        }
                        .buttonStyle(.plain)
                        .help("Resume download")
                    } else if item.isFailed {
                        Button(action: {
                            engine.retryDownload(id: item.id)
                        }) {
                            TidyIcon("dl-retry", size: 20, sfFallback: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Retry download")
                    } else if item.isCompleted {
                        if let path = item.finalFilePath {
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                            }) {
                                HStack(spacing: 4) {
                                    TidyIcon("dl-reveal", size: 14, sfFallback: "folder")
                                    Text("Reveal")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(TidyTheme.primaryRose)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(TidyTheme.roseLight))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Open")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Cancel / Remove button
                    Button(action: {
                        engine.removeDownload(id: item.id, deleteFile: false)
                    }) {
                        TidyIcon("dl-cancel", size: 18, sfFallback: "xmark")
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from list")
                }
            }
            
            // Signature Multi-Color Segment Chunk Bar (Only for active or paused)
            if item.isActive || item.isPaused {
                DownloadChunkBar(segments: item.segments, height: 7)
                
                // Speed, Sparkline, ETA, Percentage
                HStack(spacing: 12) {
                    Text(item.formattedSpeed)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.primaryRose)
                        .frame(width: 70, alignment: .leading)
                    
                    SpeedSparklineView(samples: item.speedSamples, height: 14)
                        .frame(maxWidth: 140)
                    
                    Spacer()
                    
                    Text("ETA: \(item.formattedETA)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TidyTheme.textSecondary)
                    
                    Text(item.percentageString)
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                        .frame(width: 45, alignment: .trailing)
                }
            } else if item.isCompleted {
                HStack(spacing: 6) {
                    TidyIcon("dl-verified", size: 14, sfFallback: "checkmark.seal.fill")
                    Text("Verified download • Quarantine protected")
                        .font(.system(size: 11))
                        .foregroundColor(TidyTheme.successColor)
                    Spacer()
                    if let date = item.completedAt {
                        Text(date, style: .time)
                            .font(.system(size: 10.5))
                            .foregroundColor(TidyTheme.textMuted)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(TidyTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                )
                .shadow(color: TidyTheme.cardShadow, radius: 6, y: 2)
        )
        .contextMenu {
            if item.isActive {
                Button("Pause") { engine.pauseDownload(id: item.id) }
            } else if item.isPaused {
                Button("Resume") { engine.resumeDownload(id: item.id) }
            } else if item.isFailed {
                Button("Retry") { engine.retryDownload(id: item.id) }
            }
            
            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
            }
            
            if let path = item.finalFilePath {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                Button("Open File") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
            }
            
            Divider()
            
            Button("Remove from List") {
                engine.removeDownload(id: item.id, deleteFile: false)
            }
            
            Button("Delete File to Trash", role: .destructive) {
                engine.removeDownload(id: item.id, deleteFile: true)
            }
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "images": return "cat-images"
        case "docs", "documents": return "cat-documents"
        case "sheets": return "cat-sheets"
        case "slides": return "cat-slides"
        case "archives": return "cat-archives"
        case "install", "installers": return "cat-installers"
        case "video": return "cat-video"
        case "audio": return "cat-audio"
        case "code": return "cat-code"
        default: return "dl-downloads"
        }
    }
}
