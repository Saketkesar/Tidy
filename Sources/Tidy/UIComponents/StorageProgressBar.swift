import SwiftUI

public struct StorageProgressBar: View {
    public let usedPercentage: Double
    public let height: CGFloat
    
    public init(usedPercentage: Double, height: CGFloat = 12) {
        self.usedPercentage = max(0.0, min(1.0, usedPercentage))
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background Track (Free Space)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(hex: "F5E8EE"))
                
                // Used Space Segment
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "F8719D"),
                                Color(hex: "E04B76")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(usedPercentage)))
                    .animation(.easeInOut(duration: 0.3), value: usedPercentage)
            }
        }
        .frame(height: height)
    }
}
