import SwiftUI

public struct PermissionView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    public var onDismissLimitedMode: (() -> Void)? = nil
    
    public init(onDismissLimitedMode: (() -> Void)? = nil) {
        self.onDismissLimitedMode = onDismissLimitedMode
    }
    
    public var body: some View {
        ZStack {
            TidyTheme.windowBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Hero WebP Animation (instant base64 loading, transparent, 60fps)
                AnimatedWebPView("tidy-permission.webp")
                    .frame(width: 200, height: 200)
                    .shadow(color: TidyTheme.primaryRose.opacity(0.15), radius: 20, y: 8)
                
                // Header
                VStack(spacing: 6) {
                    Text("Give Tidy Access")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(TidyTheme.textPrimary)
                    
                    Text("To find hidden caches and junk across your apps, Tidy needs Full Disk Access.\nEverything stays on your Mac. Nothing is ever uploaded.")
                        .font(.system(size: 13.5))
                        .foregroundColor(TidyTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 480)
                }
                
                // Steps Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text("1")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(TidyTheme.roseLight))
                            .foregroundColor(TidyTheme.primaryRose)
                        Text("Click \"Open System Settings\" below")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TidyTheme.textPrimary)
                    }
                    
                    HStack(spacing: 12) {
                        Text("2")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(TidyTheme.roseLight))
                            .foregroundColor(TidyTheme.primaryRose)
                        Text("Turn on the switch next to Tidy (under Full Disk Access)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TidyTheme.textPrimary)
                    }
                    
                    HStack(spacing: 12) {
                        Text("3")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(TidyTheme.roseLight))
                            .foregroundColor(TidyTheme.primaryRose)
                        Text("Return here to start cleaning")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TidyTheme.textPrimary)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(TidyTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                        )
                        .shadow(color: TidyTheme.cardShadow, radius: 10, y: 3)
                )
                .frame(maxWidth: 460)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        permissionManager.openSystemSettingsFullDiskAccess()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            Text("Open System Settings")
                        }
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(TidyTheme.primaryGradient)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        permissionManager.checkFullDiskAccess()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("I've done it - recheck")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(TidyTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9.5)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Status Indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(permissionManager.hasFullDiskAccess ? TidyTheme.successColor : TidyTheme.warningColor)
                        .frame(width: 8, height: 8)
                    Text(permissionManager.hasFullDiskAccess ? "Status: Access granted" : "Status: Waiting for permission")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TidyTheme.textSecondary)
                }
                .padding(.top, 2)
                
                // Prominent Skip / Limited Mode Button
                if !permissionManager.hasFullDiskAccess && onDismissLimitedMode != nil {
                    Button(action: {
                        onDismissLimitedMode?()
                    }) {
                        HStack(spacing: 6) {
                            Text("Skip for now & enter Limited Mode")
                                .font(.system(size: 12.5, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(TidyTheme.primaryRose)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(TidyTheme.roseLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(TidyTheme.roseSoftBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                
                Spacer()
            }
            .padding(28)
        }
        .frame(minWidth: 620, minHeight: 620)
    }
}
