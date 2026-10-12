## Why

Build a native macOS reading workspace that brings WeRead books, highlights and paragraph discussions into one window. Start with a runnable, modular foundation that can grow into a complete ebook reader.

## What Changes

- Create a Swift Package with ReaderCore, WeReadKit and a SwiftUI executable for macOS 14+.
- Add a native bookshelf, sample reader, UTF-8 TXT import, four themes and three reading layouts.
- Integrate the documented official Agent Gateway for ebook shelf, popular highlights and range-specific discussions with pagination.
- Embed the official website for authenticated full-text reading; native settings apply to the local reader, while the website retains its own settings.
- Store API keys in Keychain, keep website sessions in WebKit and label sample data explicitly.
- Add packaging, tests, macOS CI, MIT license, documentation and a public GitHub repository.

## Capabilities

### New Capabilities
- `native-reader`: Local reading, themes, layout, TXT import and persisted location.
- `weread-access`: Official website and Gateway access, shelf, highlights, anchored comments and credential handling.

### Modified Capabilities
None; this is an empty repository.

## Impact

New project, no third-party runtime dependencies. Network requests target Tencent's documented HTTPS Gateway. Full copyrighted books are displayed by the official website, not downloaded. EPUB/PDF support and native full-text WeRead rendering remain later iterations. Live Gateway validation requires the user's API key and is outside the scaffold's automated fixture checks.
