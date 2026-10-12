## Context
Empty macOS repository; Command Line Tools available, full Xcode absent. Tencent publishes an Agent Gateway and official interface documentation (reviewed 2026-10-12). No account key is supplied.

## Goals / Non-Goals
Goals: runnable native app; useful offline demo; local TXT reading; official book shelf and paragraph discussions; stable module boundaries; reproducible builds.
Non-goals: EPUB/PDF rendering in this iteration, full-text extraction, mobile-app reverse engineering, credential scraping, offline WeRead books, comment publishing.

## Decisions
- Swift Package with SwiftUI/AppKit/WebKit and macOS 14 minimum. Native UI and no runtime dependencies; Electron/Tauri add unnecessary packaging and bridge complexity here.
- ReaderCore contains models, paragraph anchors and local imports. WeReadKit owns Gateway transport and DTO mapping. App owns views, Keychain and persistence.
- Gateway POST uses top-level `api_name`, `skill_version` (1.0.5) and business parameters. WeRead comments use the exact bookId + chapterUid + range returned by the API; never infer range from rendered Chinese text offsets.
- Read ebook shelf via `/shelf/sync`; popular excerpts via `/book/bestbookmarks`; comments via `/book/readreviews`. Popular highlights are capped by the service at 20. The bookshelf is explicitly labelled electronic books; audio and article collections are future providers.
- Native reader modes cover local books and excerpt lists. Paginated mode groups four paragraphs per page (not typographic pagination); focus mode hides navigation. Official website retains its own typography and themes.
- Website session stays inside the default WebKit data store. API key stays in macOS Keychain; it is never in UserDefaults or a repository file. Logout can separately clear website data.
- Async selection checks prevent slow responses for one paragraph from overwriting another; comments paginate with the server's maxIdx/synckey, deduplicate by ID, and preserve earlier pages on errors.
- Preferences, imported text and book-specific paragraph location persist locally in Application Support / UserDefaults. No account shelf or comments persisted in this iteration.

## Risks / Trade-offs
- Gateway schema/version changes → isolated adapter, fixture tests, upgrade_info stops operation and prompts update.
- Authenticated website login differs across WebKit/SSO flows → built-in navigation + external Safari fallback; no fabricated reader URLs.
- No API key supplied → fixtures validate request/response handling; document that account-backed integration still needs live acceptance.
- Unsigned local app → ad-hoc build for local use; signing/notarization remains release work.

## Migration Plan
Create scaffold and verify swift build/test, package a local .app, publish new public repository. No prior data migration. Future format providers extend ReaderCore without changing the Gateway.

## Open Questions
Live schema compatibility and WebKit authentication behavior require an account-backed manual check. EPUB/PDF priority and font-aware page layout will be decided in later changes.
