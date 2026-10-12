import Foundation
import ReaderCore

struct LibraryStore {
    let directory: URL
    init() throws {
        directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("WeReadMac", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    private var url: URL { directory.appendingPathComponent("local-library.json") }
    func load() throws -> [LocalBook] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([LocalBook].self, from: Data(contentsOf: url))
    }
    func save(_ books: [LocalBook]) throws {
        try JSONEncoder().encode(books).write(to: url, options: .atomic)
    }
}
