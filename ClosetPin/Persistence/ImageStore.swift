import Foundation

struct ImageStore {
    let baseDirectory: URL

    private static let defaultDirectoryName = "WardrobeImages"

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(Self.defaultDirectoryName, isDirectory: true)
        }
    }

    func saveJPEGData(_ data: Data, id: UUID) throws -> URL {
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let url = baseDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: url, options: [.atomic])
        return url
    }

    func storagePath(for url: URL) -> String {
        guard url.path.hasPrefix(baseDirectory.path) else { return url.path }
        let relativePath = url.path
            .replacingOccurrences(of: baseDirectory.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return [Self.defaultDirectoryName, relativePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    static func localURL(for storedPath: String) -> URL? {
        let trimmedPath = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: trimmedPath) {
            return URL(fileURLWithPath: trimmedPath)
        }

        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let relativeURL = documentsDirectory.appendingPathComponent(trimmedPath)
        if fileManager.fileExists(atPath: relativeURL.path) {
            return relativeURL
        }

        let filename = (trimmedPath as NSString).lastPathComponent
        guard !filename.isEmpty else { return nil }

        let currentOriginalURL = documentsDirectory
            .appendingPathComponent(defaultDirectoryName, isDirectory: true)
            .appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(filename)
        if trimmedPath.contains("/Originals/") || trimmedPath.hasPrefix("\(defaultDirectoryName)/Originals/"),
           fileManager.fileExists(atPath: currentOriginalURL.path) {
            return currentOriginalURL
        }

        let currentStoreURL = documentsDirectory
            .appendingPathComponent(defaultDirectoryName, isDirectory: true)
            .appendingPathComponent(filename)
        if fileManager.fileExists(atPath: currentStoreURL.path) {
            return currentStoreURL
        }

        if fileManager.fileExists(atPath: currentOriginalURL.path) {
            return currentOriginalURL
        }

        return nil
    }
}
