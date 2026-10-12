import Foundation
import ReaderCore

struct LibraryStore: Sendable {
    let directory: URL
    init(directory suppliedDirectory: URL? = nil) throws {
        directory = try suppliedDirectory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("WeReadMac", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    private var url: URL { directory.appendingPathComponent("local-library.json") }
    func load() throws -> LocalLibraryArchive {
        guard FileManager.default.fileExists(atPath: url.path) else { return LocalLibraryArchive() }
        return try LocalLibraryArchive.decode(Data(contentsOf: url, options: .mappedIfSafe))
    }
    func save(_ archive: LocalLibraryArchive) throws {
        try JSONEncoder().encode(archive).write(to: url, options: .atomic)
    }
}
