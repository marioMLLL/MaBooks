import Foundation
import Testing
@testable import ReaderCore

@Test func hundredMiBIsAcceptedAndLargerFilesAreRejected() throws {
    try TXTImportPolicy.validateSize(100 * 1024 * 1024)
    #expect(throws: TXTImportError.self) { try TXTImportPolicy.validateSize(100 * 1024 * 1024 + 1) }
}

@Test func deletedBooksCanBeRestoredWithStableParagraphsAfterSaving() throws {
    let book = LocalBook.importing(text: "原创测试第一段\n原创测试第二段", title: "删除测试", id: "delete-fixture")
    let legacy = try JSONEncoder().encode([book])
    var archive = try LocalLibraryArchive.decode(legacy)
    #expect(archive.deletedBooks.isEmpty)
    let deleted = archive.delete(bookID: book.book.id)
    #expect(deleted)
    #expect(archive.books.isEmpty)
    let sampleDeleted = archive.delete(bookID: "sample-reading")
    #expect(!sampleDeleted)
    archive = try LocalLibraryArchive.decode(JSONEncoder().encode(archive))
    let restored = archive.restore(bookID: book.book.id)
    #expect(restored)
    #expect(archive.deletedBooks.isEmpty)
    #expect(archive.books[0].paragraphs == book.paragraphs)
    let restoredAgain = archive.restore(bookID: book.book.id)
    #expect(!restoredAgain)
}

@Test func actualHundredMiBTXTCanBeImportedAndPersisted() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("synthetic-100MiB.txt")
    FileManager.default.createFile(atPath: file.path, contents: nil)
    let handle = try FileHandle(forWritingTo: file)
    let chunk = Data((String(repeating: "a", count: 1024 * 1024 - 1) + "\n").utf8)
    for _ in 0..<100 { try handle.write(contentsOf: chunk) }
    try handle.close()
    let book = try TXTImportPolicy.read(file)
    #expect(book.paragraphs.count == 100)
    #expect(book.paragraphs.allSatisfy { $0.text.utf8.count == 1024 * 1024 - 1 })
    let archiveFile = directory.appendingPathComponent("archive.json")
    try JSONEncoder().encode(LocalLibraryArchive(books: [book])).write(to: archiveFile, options: .atomic)
    let archive = try LocalLibraryArchive.decode(Data(contentsOf: archiveFile, options: .mappedIfSafe))
    #expect(archive.books[0].book.id == book.book.id)
    #expect(archive.books[0].paragraphs.count == 100)
}
