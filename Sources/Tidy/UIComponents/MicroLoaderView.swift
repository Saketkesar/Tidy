import SwiftUI

public struct MicroLoaderView: View {
    public let size: CGFloat
    
    public init(size: CGFloat = 20) {
        self.size = size
    }
    
    public var body: some View {
        AnimatedWebPView("tidy-microloader.webp")
            .frame(width: size, height: size)
    }
}
