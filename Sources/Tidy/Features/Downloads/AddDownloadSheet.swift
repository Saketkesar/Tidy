import SwiftUI
import AppKit

@MainActor
public class AddDownloadViewModel: ObservableObject {
    @Published public var urlString: String = ""
    @Published public var isProbing: Bool = false
    @Published public var probeResult: ProbeResult? = nil
    @Published public var probeError: String? = nil
    
    @Published public var destinationFolder: String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    @Published public var selectedCategory: String = "Auto"
    @Published public var connections: Int = 8
    @Published public var duplicateExists: Bool = false
    @Published public var duplicateChoice: String = "rename" // rename, replace, skip
    
    public init() {}
    
    public func probe() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https" else {
            probeError = "Please enter a valid http:// or https:// URL"
            return
        }
        
        isProbing = true
        probeError = nil
        probeResult = nil
        
        Task {
            do {
                let result = try await DownloadEngine.shared.probeURL(url)
                self.probeResult = result
                self.selectedCategory = result.category
                self.isProbing = false
                self.checkDuplicate(fileName: result.fileName)
            } catch {
                self.probeError = "Could not reach server: \(error.localizedDescription)"
                self.isProbing = false
            }
        }
    }
    
    public func checkDuplicate(fileName: String) {
        let dest = URL(fileURLWithPath: destinationFolder).appendingPathComponent(fileName)
        self.duplicateExists = FileManager.default.fileExists(atPath: dest.path)
    }
}

public struct AddDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddDownloadViewModel()
    @ObservedObject var diskInfo = DiskInfoService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                TidyIcon("dl-add-url", size: 32, sfFallback: "arrow.down.circle.fill")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Download")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Multi-connection fast downloader with real-time chunk progress.")
                        .font(.system(size: 11.5))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(TidyTheme.textSecondary)
            }
            .padding(18)
            .background(TidyTheme.cardBackground)
            
            Divider().opacity(0.4)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // URL Input field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DOWNLOAD URL")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(TidyTheme.textSecondary)
                        
                        HStack(spacing: 8) {
                            TextField("Paste http:// or https:// link here...", text: $viewModel.urlString)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(TidyTheme.innerCardBackground)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                                )
                                .onSubmit {
                                    viewModel.probe()
                                }
                            
                            Button(action: {
                                if let clip = NSPasteboard.general.string(forType: .string) {
                                    viewModel.urlString = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                    viewModel.probe()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste")
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(TidyTheme.primaryRose)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            
                            Button(action: {
                                viewModel.probe()
                            }) {
                                HStack(spacing: 6) {
                                    if viewModel.isProbing {
                                        MicroLoaderView(size: 13)
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                    Text("Probe")
                                        .font(.system(size: 11.5, weight: .bold))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TidyTheme.primaryRose)
                            .disabled(viewModel.urlString.isEmpty || viewModel.isProbing)
                        }
                        
                        if let err = viewModel.probeError {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(TidyTheme.dangerColor)
                        }
                    }
                    
                    // Probe details card
                    if let probe = viewModel.probeResult {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                TidyIcon(categoryIconName(probe.category), size: 36, sfFallback: "doc.fill")
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(probe.fileName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(TidyTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 8) {
                                        if let size = probe.totalBytes {
                                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                                .font(.system(size: 11.5, weight: .semibold))
                                                .foregroundColor(TidyTheme.primaryRose)
                                        } else {
                                            Text("Unknown size (stream)")
                                                .font(.system(size: 11.5))
                                                .foregroundColor(TidyTheme.textSecondary)
                                        }
                                        
                                        Text("•")
                                            .foregroundColor(TidyTheme.textMuted)
                                        
                                        Text(probe.finalURL.host ?? "server")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(TidyTheme.textSecondary)
                                        
                                        Text("•")
                                            .foregroundColor(TidyTheme.textMuted)
                                        
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(probe.resumable ? TidyTheme.successColor : TidyTheme.warningColor)
                                                .frame(width: 6, height: 6)
                                            Text(probe.resumable ? "Resumable" : "Single stream")
                                                .font(.system(size: 10.5, weight: .semibold))
                                                .foregroundColor(probe.resumable ? TidyTheme.successColor : TidyTheme.warningColor)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            
                            Divider().opacity(0.3)
                            
                            // Destination & Category
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Save To:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(TidyTheme.textSecondary)
                                        .frame(width: 90, alignment: .leading)
                                    
                                    Text(viewModel.destinationFolder)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(TidyTheme.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button("Browse...") {
                                        chooseFolderDialog()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                HStack {
                                    Text("Category:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(TidyTheme.textSecondary)
                                        .frame(width: 90, alignment: .leading)
                                    
                                    Picker("", selection: $viewModel.selectedCategory) {
                                        Text("Images").tag("Images")
                                        Text("Docs").tag("Docs")
                                        Text("Sheets").tag("Sheets")
                                        Text("Slides").tag("Slides")
                                        Text("Archives").tag("Archives")
                                        Text("Install").tag("Install")
                                        Text("Video").tag("Video")
                                        Text("Audio").tag("Audio")
                                        Text("Code").tag("Code")
                                        Text("Other").tag("Other")
                                    }
                                    .labelsHidden()
                                    .frame(width: 150)
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Connections:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(TidyTheme.textSecondary)
                                        .frame(width: 90, alignment: .leading)
                                    
                                    Slider(value: Binding(
                                        get: { Double(viewModel.connections) },
                                        set: { viewModel.connections = Int($0) }
                                    ), in: 1...16, step: 1)
                                    .frame(maxWidth: 160)
                                    .disabled(!probe.resumable)
                                    
                                    Text("\(viewModel.connections) streams")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(probe.resumable ? TidyTheme.primaryRose : TidyTheme.textMuted)
                                    
                                    Spacer()
                                }
                            }
                            
                            // Disk capacity check
                            if let total = probe.totalBytes {
                                HStack(spacing: 6) {
                                    if diskInfo.freeBytes < total {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(TidyTheme.dangerColor)
                                        Text("Insufficient disk space! (Need \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)), only \(diskInfo.formattedFree) available)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(TidyTheme.dangerColor)
                                    } else {
                                        Image(systemName: "internaldrive")
                                            .foregroundColor(TidyTheme.successColor)
                                        Text("Disk space verified (\(diskInfo.formattedFree) available)")
                                            .font(.system(size: 11))
                                            .foregroundColor(TidyTheme.textSecondary)
                                    }
                                }
                            }
                            
                            // Duplicate Guard
                            if viewModel.duplicateExists {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(TidyTheme.warningColor)
                                    Text("File already exists in destination folder. Duplicate will be saved with a counter like '(2)'.")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(TidyTheme.textPrimary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(TidyTheme.warningColor.opacity(0.12)))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(TidyTheme.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(TidyTheme.roseSoftBorder, lineWidth: 1))
                                .shadow(color: TidyTheme.cardShadow, radius: 6, y: 2)
                        )
                    }
                }
                .padding(20)
            }
            
            Divider().opacity(0.4)
            
            // Footer Action
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button(action: startDownloadAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(TidyTheme.primaryGradient)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.probeResult == nil)
            }
            .padding(16)
            .background(TidyTheme.cardBackground)
        }
        .frame(minWidth: 540, minHeight: 440)
    }
    
    private func chooseFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.destinationFolder = url.path
            if let probe = viewModel.probeResult {
                viewModel.checkDuplicate(fileName: probe.fileName)
            }
        }
    }
    
    private func startDownloadAction() {
        guard let probe = viewModel.probeResult,
              let url = URL(string: viewModel.urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        
        _ = DownloadEngine.shared.addDownload(
            url: url,
            probe: probe,
            destinationFolder: viewModel.destinationFolder,
            category: viewModel.selectedCategory,
            connections: viewModel.connections,
            startImmediately: true
        )
        dismiss()
    }
    
    private func categoryIconName(_ folder: String) -> String {
        switch folder.lowercased() {
        case "images": return "cat-images"
        case "docs", "documents": return "cat-documents"
        case "sheets": return "cat-sheets"
        case "slides": return "cat-slides"
        case "archives": return "cat-archives"
        case "install", "installers": return "cat-installers"
        case "video": return "cat-video"
        case "audio": return "cat-audio"
        case "code": return "cat-code"
        default: return "cat-other"
        }
    }
}
