import SwiftUI

public struct StartupItemsView: View {
    @StateObject private var viewModel = StartupItemsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Startup Items")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("Login items and background agents that run automatically when your Mac starts.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                Spacer()
                Button(action: {
                    viewModel.scanStartupItems()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(TidyTheme.textSecondary)
                }
                .buttonStyle(.bordered)
            }
            
            // Notice Card
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(TidyTheme.primaryRose)
                Text("Background items can also be enabled or disabled in macOS System Settings > General > Login Items.")
                    .font(.system(size: 12))
                    .foregroundColor(TidyTheme.textSecondary)
                Spacer()
                Button("Open System Settings") {
                    viewModel.openSystemSettingsLoginItems()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(TidyTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                    )
            )
            
            Divider()
                .opacity(0.5)
            
            if viewModel.isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    AnimatedWebPView("tidy-cleaning-1080.webp")
                        .frame(width: 160, height: 160)
                    Text("Reading startup items from system...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bolt.horizontal.circle")
                        .font(.system(size: 48))
                        .foregroundColor(TidyTheme.textMuted)
                    Text("No startup items found")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TidyTheme.textPrimary)
                    Text("No user LaunchAgents or Login Items were detected.")
                        .font(.system(size: 13))
                        .foregroundColor(TidyTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.items) { item in
                            HStack(spacing: 14) {
                                TidyIcon("startup", size: 28, sfFallback: "bolt.fill")
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(TidyTheme.textPrimary)
                                    HStack(spacing: 6) {
                                        Text(item.developer)
                                            .font(.system(size: 11))
                                            .foregroundColor(TidyTheme.textSecondary)
                                        Text("•")
                                            .foregroundColor(TidyTheme.textMuted)
                                        Text(item.type.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(TidyTheme.primaryRose)
                                    }
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { _ in viewModel.toggleItem(item) }
                                ))
                                .toggleStyle(.switch)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(TidyTheme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                    )
                                    .shadow(color: TidyTheme.cardShadow, radius: 4, y: 2)
                            )
                        }
                    }
                }
            }
        }
        .padding(28)
        .background(TidyTheme.windowBackground)
    }
}
