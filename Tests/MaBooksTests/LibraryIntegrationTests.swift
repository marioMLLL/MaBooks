import AppKit
import Foundation
import Testing
import ReaderCore
import ReaderLayoutKit
@testable import MaBooks

@MainActor
private func waitForLibrary(_ state: AppState) async throws {
    let deadline = Date().addingTimeInterval(10)
    while state.libraryBusy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
    #expect(!state.libraryBusy)
    #expect(state.notice == nil)
}

@Test @MainActor func deletingTheOpenBookCanBeRestoredAndReopenedAtItsTextPosition() async throws {
    _ = NSApplication.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try LibraryStore(directory: directory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("synthetic-source.txt")
    try String(repeating: "原创验收文字可以跨越多页，并在删除恢复后继续阅读。", count: 120).write(to: source, atomically: true, encoding: .utf8)
    let local = try TXTImportPolicy.read(source)
    try store.save(LocalLibraryArchive(books: [local]))
    let state = AppState(libraryStore: store, loadCredential: false)
    try await waitForLibrary(state)
    state.open(local.book)
    let pages = PageLayout(document: state.readingDocument, size: CGSize(width: 300, height: 250), fontSize: 20, color: .black)
    state.setPageRanges(pages.ranges, bookID: local.book.id)
    state.navigatePage(1)
    let offset = state.readingOffset
    #expect(offset > 0)
    state.deleteLocalBook(local.book)
    try await waitForLibrary(state)
    #expect(state.selectedBook.source == .sample)
    #expect(state.localBooks.isEmpty)
    #expect(state.deletedBooks.count == 1)
    #expect(FileManager.default.fileExists(atPath: source.path))
    state.restoreLocalBook(local.book)
    try await waitForLibrary(state)
    let restarted = AppState(libraryStore: store, loadCredential: false)
    try await waitForLibrary(restarted)
    restarted.open(local.book)
    restarted.setPageRanges(pages.ranges, bookID: local.book.id)
    #expect(restarted.page == 1)
    #expect(restarted.readingOffset == offset)
    #expect(restarted.localBooks[0].paragraphs == local.paragraphs)
    UserDefaults.standard.removeObject(forKey: "position.\(local.book.id)")
    UserDefaults.standard.removeObject(forKey: "position.offset.\(local.book.id)")
}
