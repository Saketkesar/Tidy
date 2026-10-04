import SwiftUI

public struct DownloadChunkBar: View {
    public let segments: [DownloadSegment]
    public let height: CGFloat
    
    private let pastelPalette: [Color] = [
        Color(hex: "F2678F"), // Rose
        Color(hex: "34D399"), // Mint
        Color(hex: "38BDF8"), // Sky
        Color(hex: "A78BFA"), // Lavender
        Color(hex: "FBBF24"), // Peach
        Color(hex: "FB7185"), // Coral
        Color(hex: "2DD4BF"), // Teal
        Color(hex: "818CF8")  // Indigo
    ]
    
    public init(segments: [DownloadSegment], height: CGFloat = 8) {
        self.segments = segments
        self.height = height
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            if segments.isEmpty {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(TidyTheme.roseSoftBorder)
                    .frame(height: height)
            } else {
                ForEach(segments) { seg in
                    let color = pastelPalette[seg.index % pastelPalette.count]
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Segment background track
                            RoundedRectangle(cornerRadius: height / 2)
                                .fill(color.opacity(0.18))
                            
                            // Segment active progress fill
                            RoundedRectangle(cornerRadius: height / 2)
                                .fill(color)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(seg.progress))))
                        }
                    }
                    .frame(height: height)
                }
            }
        }
        .frame(height: height)
    }
}

public struct SpeedSparklineView: View {
    public let samples: [Double]
    public let height: CGFloat
    
    public init(samples: [Double], height: CGFloat = 16) {
        self.samples = samples
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            if samples.count > 1, let maxVal = samples.max(), maxVal > 0 {
                let stepX = w / CGFloat(max(1, samples.count - 1))
                
                ZStack {
                    // Soft Area Gradient
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        for (idx, val) in samples.enumerated() {
                            let x = CGFloat(idx) * stepX
                            let normalized = CGFloat(val / maxVal)
                            let y = h - (normalized * (h - 2))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: CGFloat(samples.count - 1) * stepX, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [TidyTheme.primaryRose.opacity(0.2), TidyTheme.primaryRose.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Line Path
                    Path { path in
                        for (idx, val) in samples.enumerated() {
                            let x = CGFloat(idx) * stepX
                            let normalized = CGFloat(val / maxVal)
                            let y = h - (normalized * (h - 2))
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(TidyTheme.primaryRose, lineWidth: 1.5)
                }
            } else {
                // Baseline track
                Rectangle()
                    .fill(TidyTheme.roseSoftBorder)
                    .frame(height: 1)
                    .position(x: w / 2, y: h - 1)
            }
        }
        .frame(height: height)
    }
}
