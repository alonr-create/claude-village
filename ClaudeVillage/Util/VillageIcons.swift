import AppKit
import SwiftUI
import SpriteKit

/// Village icon system — loads custom Nano Banana PNG icons with emoji fallbacks
enum VillageIcons {
    private static var cache: [String: NSImage] = [:]

    /// Load an icon NSImage by name from Resources/icons/
    static func image(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }

        let searchPaths = [
            Bundle.main.resourcePath.map { $0 + "/icons/\(name).png" },
            Bundle.main.bundlePath + "/Contents/Resources/icons/\(name).png",
            "./ClaudeVillage/Resources/icons/\(name).png",
            "./Resources/icons/\(name).png",
        ].compactMap { $0 }

        for path in searchPaths {
            if let img = NSImage(contentsOfFile: path) {
                cache[name] = img
                return img
            }
        }
        return nil
    }

    /// SpriteKit texture from icon
    static func texture(_ name: String) -> SKTexture? {
        guard let img = image(name) else { return nil }
        return SKTexture(image: img)
    }
}

/// SwiftUI view that shows a village icon with emoji fallback
struct VillageIconView: View {
    let name: String
    let size: CGFloat
    let fallback: String

    init(_ name: String, size: CGFloat = 16, fallback: String = "?") {
        self.name = name
        self.size = size
        self.fallback = fallback
    }

    var body: some View {
        if let nsImage = VillageIcons.image(name) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Text(fallback)
                .font(.system(size: size * 0.8))
        }
    }
}
