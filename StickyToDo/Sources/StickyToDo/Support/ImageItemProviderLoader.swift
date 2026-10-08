import AppKit
import UniformTypeIdentifiers

/// Loads an NSImage from an NSItemProvider (drag-and-drop or paste) by reading
/// whichever registered type identifier the provider actually offers that
/// conforms to .image, then constructing the image from raw data. This covers
/// vector formats like SVG that NSImage's NSItemProviderReading conformance
/// (loadObject(ofClass: NSImage.self)) does not reliably pick up.
enum ImageItemProviderLoader {
    static func loadImage(from provider: NSItemProvider, completion: @escaping (NSImage?) -> Void) {
        guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) else {
            completion(nil)
            return
        }

        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
            completion(data.flatMap { NSImage(data: $0) })
        }
    }
}
