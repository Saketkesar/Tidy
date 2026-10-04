import SwiftUI
import AppKit
import QuartzCore
import ImageIO

public struct AnimatedWebPData {
    public let frames: [CGImage]
    public let keyTimes: [NSNumber]
    public let totalDuration: Double
}

public final class WebPAnimationCache {
    public static let shared = WebPAnimationCache()
    private var cache: [String: AnimatedWebPData] = [:]
    private var firstFrameCache: [String: CGImage] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    public func getFirstFrame(for fileName: String) -> CGImage? {
        let key = normalizeKey(fileName)
        lock.lock()
        if let existing = firstFrameCache[key] {
            lock.unlock()
            return existing
        }
        if let existingAnim = cache[key]?.frames.first {
            lock.unlock()
            return existingAnim
        }
        lock.unlock()
        
        guard let url = resolveFileURL(name: key),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 400,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        let img = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        
        if let img = img {
            lock.lock()
            firstFrameCache[key] = img
            lock.unlock()
        }
        return img
    }
    
    public func getAnimation(for fileName: String) -> AnimatedWebPData? {
        let key = normalizeKey(fileName)
        
        lock.lock()
        if let existing = cache[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()
        
        guard let url = resolveFileURL(name: key),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }
        
        let step = frameCount > 60 ? 2 : 1
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 400,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        var images: [CGImage] = []
        images.reserveCapacity(frameCount / step + 1)
        var durations: [Double] = []
        durations.reserveCapacity(frameCount / step + 1)
        var totalDuration: Double = 0.0
        
        for i in stride(from: 0, to: frameCount, by: step) {
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, i, thumbOptions as CFDictionary)
                    ?? CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            images.append(image)
            
            var frameDuration: Double = 0.033 * Double(step)
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let webpProps = properties[kCGImagePropertyWebPDictionary] as? [CFString: Any] {
                let unclamped = webpProps["UnclampedDelayTime" as CFString] as? Double
                let delay = webpProps["DelayTime" as CFString] as? Double
                let chosen = unclamped ?? delay ?? 0.033
                let actual = chosen > 0.01 ? chosen : 0.033
                frameDuration = actual * Double(step)
            }
            durations.append(frameDuration)
            totalDuration += frameDuration
        }
        
        guard !images.isEmpty, totalDuration > 0 else { return nil }
        
        var keyTimes: [NSNumber] = []
        keyTimes.reserveCapacity(images.count)
        var accumulated: Double = 0.0
        for dur in durations {
            keyTimes.append(NSNumber(value: accumulated / totalDuration))
            accumulated += dur
        }
        
        let data = AnimatedWebPData(frames: images, keyTimes: keyTimes, totalDuration: totalDuration)
        
        lock.lock()
        cache[key] = data
        if let first = images.first {
            firstFrameCache[key] = first
        }
        lock.unlock()
        
        return data
    }
    
    public func loadAsync(for fileName: String, completion: @escaping (AnimatedWebPData?) -> Void) {
        let key = normalizeKey(fileName)
        lock.lock()
        if let existing = cache[key] {
            lock.unlock()
            completion(existing)
            return
        }
        lock.unlock()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let data = self.getAnimation(for: fileName)
            DispatchQueue.main.async {
                completion(data)
            }
        }
    }
    
    private func normalizeKey(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.isEmpty ? "webp" : (fileName as NSString).pathExtension
        return "\(base).\(ext)"
    }
    
    private func resolveFileURL(name: String) -> URL? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "webp" : (name as NSString).pathExtension
        let fullName = "\(base).\(ext)"
        
        let directWorkspacePaths = [
            "/Users/saketkesar/Downloads/dinly/Tidy/\(fullName)",
            "/Users/saketkesar/Downloads/dinly/Tidy/Resources/\(fullName)",
            "./\(fullName)",
            "./Resources/\(fullName)"
        ]
        for p in directWorkspacePaths {
            if FileManager.default.fileExists(atPath: p) {
                return URL(fileURLWithPath: p)
            }
        }
        
        if let resURL = Bundle.main.resourceURL {
            let bundleFile = resURL.appendingPathComponent(fullName)
            if FileManager.default.fileExists(atPath: bundleFile.path) {
                return bundleFile
            }
        }
        
        if let url = Bundle.main.url(forResource: base, withExtension: ext) {
            return url
        }
        
        return nil
    }
}

public final class NativeWebPPlayerView: NSView {
    private let imageLayer = CALayer()
    public private(set) var currentFileName: String? = nil
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer?.backgroundColor = .clear
        
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.backgroundColor = .clear
        imageLayer.isOpaque = false
        layer?.addSublayer(imageLayer)
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        CATransaction.commit()
    }
    
    public func setAnimation(fileName: String) {
        if currentFileName == fileName {
            return
        }
        currentFileName = fileName
        
        // Show first frame instantly without blocking
        if let first = WebPAnimationCache.shared.getFirstFrame(for: fileName) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.contents = first
            CATransaction.commit()
        }
        
        // Load full animated sequence
        WebPAnimationCache.shared.loadAsync(for: fileName) { [weak self] data in
            guard let self = self, self.currentFileName == fileName, let data = data else { return }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.imageLayer.contents = data.frames.first
            CATransaction.commit()
            
            if data.frames.count > 1 {
                let animation = CAKeyframeAnimation(keyPath: "contents")
                animation.values = data.frames
                animation.keyTimes = data.keyTimes
                animation.duration = data.totalDuration
                animation.calculationMode = .discrete
                animation.repeatCount = .infinity
                animation.isRemovedOnCompletion = false
                self.imageLayer.removeAnimation(forKey: "webpAnimation")
                self.imageLayer.add(animation, forKey: "webpAnimation")
            } else {
                self.imageLayer.removeAnimation(forKey: "webpAnimation")
            }
        }
    }
}

public struct AnimatedWebPView: NSViewRepresentable {
    public let fileName: String
    
    public init(_ fileName: String) {
        self.fileName = fileName
    }
    
    public func makeNSView(context: Context) -> NativeWebPPlayerView {
        let view = NativeWebPPlayerView(frame: .zero)
        view.setAnimation(fileName: fileName)
        return view
    }
    
    public func updateNSView(_ nsView: NativeWebPPlayerView, context: Context) {
        if nsView.currentFileName != fileName {
            nsView.setAnimation(fileName: fileName)
        }
    }
}
