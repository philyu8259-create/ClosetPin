import XCTest
@testable import ClosetPin

final class ImageStoreTests: XCTestCase {
    func testSavesJPEGDataToWardrobeDirectoryAndReturnsFileURL() throws {
        let directory = temporaryDirectory()
        let store = ImageStore(baseDirectory: directory)
        let data = Data([0x01, 0x02, 0x03])

        let url = try store.saveJPEGData(data, id: UUID())

        XCTAssertEqual(url.deletingLastPathComponent(), directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testCreatesWardrobeDirectoryWhenMissing() throws {
        let directory = temporaryDirectory(create: false)
        let store = ImageStore(baseDirectory: directory)

        _ = try store.saveJPEGData(Data([0x04]), id: UUID())

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testUsesSuppliedUUIDAsJPEGFilename() throws {
        let directory = temporaryDirectory()
        let store = ImageStore(baseDirectory: directory)
        let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

        let url = try store.saveJPEGData(Data([0x05]), id: id)

        XCTAssertEqual(url.lastPathComponent, "12345678-1234-1234-1234-123456789ABC.jpg")
    }

    func testSavingSameUUIDOverwritesExistingJPEGData() throws {
        let directory = temporaryDirectory()
        let store = ImageStore(baseDirectory: directory)
        let id = UUID()
        let originalData = Data([0x06, 0x07])
        let replacementData = Data([0x08, 0x09, 0x0A])

        let originalURL = try store.saveJPEGData(originalData, id: id)
        let replacementURL = try store.saveJPEGData(replacementData, id: id)

        XCTAssertEqual(replacementURL, originalURL)
        XCTAssertEqual(try Data(contentsOf: replacementURL), replacementData)
    }

    func testPropagatesWriteErrorWhenTargetURLIsDirectory() throws {
        let directory = temporaryDirectory()
        let store = ImageStore(baseDirectory: directory)
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let targetDirectory = directory.appendingPathComponent("\(id.uuidString).jpg", isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        XCTAssertThrowsError(try store.saveJPEGData(Data([0x0B]), id: id))
    }
}

private extension ImageStoreTests {
    func temporaryDirectory(create: Bool = true) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        if create {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        return directory
    }
}
