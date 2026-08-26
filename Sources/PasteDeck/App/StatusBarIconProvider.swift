import AppKit

enum StatusBarIconProvider {
    static let resourceName = "MenuBarIcon"
    static let logicalSize = NSSize(width: 18, height: 18)

    static func image(bundle: Bundle = .main) -> NSImage {
        // Xcode combines the 1x and 2x PNG pair into one multi-representation TIFF.
        if let url = bundle.url(forResource: resourceName, withExtension: "tiff"),
           let image = NSImage(contentsOf: url) {
            return configure(image)
        }

        if let image = bundledImage(bundle: bundle) {
            return configure(image)
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let fallback = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "PasteDeck"
        )?.withSymbolConfiguration(configuration) ?? NSImage(size: logicalSize)
        return configure(fallback)
    }

    private static func bundledImage(bundle: Bundle) -> NSImage? {
        let image = NSImage(size: logicalSize)

        for name in [resourceName, "\(resourceName)@2x"] {
            guard let url = bundle.url(forResource: name, withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let representation = NSBitmapImageRep(data: data) else {
                continue
            }
            representation.size = logicalSize
            image.addRepresentation(representation)
        }

        return image.representations.isEmpty ? nil : image
    }

    private static func configure(_ image: NSImage) -> NSImage {
        image.size = logicalSize
        image.isTemplate = true
        image.accessibilityDescription = "PasteDeck"
        return image
    }
}
