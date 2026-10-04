import SwiftUI

public struct MovePreviewSheet: View {
    public let plan: OrganizePlan
    public var onCancel: () -> Void
    public var onConfirm: () -> Void
    
    public init(plan: OrganizePlan, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        self.plan = plan
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview — \(plan.moves.count) files will move")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Total size: \(ByteCountFormatter.string(fromByteCount: plan.totalBytesToMove, countStyle: .file))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Moves List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(plan.moves) { move in
                        HStack(spacing: 12) {
                            FileIconView(url: move.sourceURL)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(move.fileName)
                                    .font(.system(size: 13, weight: .medium))
                                Text(move.formattedSize)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text("Sorted/\(move.targetSubfolder)/")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(TidyTheme.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(TidyTheme.accentColor.opacity(0.1))
                                )
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }
            }
            .frame(maxHeight: 360)
            
            // Skipped Notice
            if !plan.skipped.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Skipped: \(plan.skipped.count) (still downloading, hidden, folders, or already sorted)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: onConfirm) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.gearshape")
                        Text("Organize \(plan.moves.count) files")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(TidyTheme.accentColor)
                .disabled(plan.moves.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 580, height: 500)
    }
}
