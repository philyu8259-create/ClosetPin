import Foundation

struct ImageStore {
    let baseDirectory: URL

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WardrobeImages", isDirectory: true)
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
}
