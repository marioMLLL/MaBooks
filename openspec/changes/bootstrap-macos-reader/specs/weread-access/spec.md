## ADDED Requirements

### Requirement: Official Gateway integration
The app SHALL use the official HTTPS Agent Gateway with Bearer auth, top-level parameters and a version field to retrieve ebook shelf, popular highlights and discussions.

#### Scenario: Retrieve highlights
- **WHEN** an authenticated user selects a shelf book
- **THEN** the app SHALL request popular highlights and preserve their exact book, chapter and range anchors

### Requirement: Range-specific comments
The app SHALL fetch and paginate comments for the selected exact anchor, and SHALL never replace a selection with a response for a different anchor.

#### Scenario: Selection changes while loading
- **WHEN** the user selects paragraph B while A's request is pending
- **THEN** A's result SHALL be discarded if it arrives after the selection changed

#### Scenario: More comments
- **WHEN** the response reports hasMore
- **THEN** the next request SHALL use returned maxIdx and synckey and append unique comments

### Requirement: Credentials and errors
The API key SHALL be stored only in Keychain. Auth, transport, decoding and required upgrade failures SHALL appear as recoverable UI errors without credentials or silent demo fallback.

#### Scenario: Required version update
- **WHEN** the Gateway returns upgrade_info
- **THEN** the app SHALL stop processing that response and explain that the integration needs updating

### Requirement: Official full-text reader
The app SHALL provide a persistent WebKit view of the official website and accept only official HTTPS reader URLs for in-app book navigation.

#### Scenario: Explain native content availability
- **WHEN** a user opens a synced WeRead shelf entry
- **THEN** the app SHALL label native content as highlight excerpts, disclose that full book text is not stored locally, and label full-text navigation as official web reading

#### Scenario: Book has no reader link
- **WHEN** the selected book lacks an official HTTPS readerLink
- **THEN** the app SHALL offer the official homepage without inventing a book URL

#### Scenario: Read a shelf entry
- **WHEN** a user selects a WeRead shelf book
- **THEN** the app SHALL open its official reader inside the app, refresh metadata using the official book info endpoint, and keep highlights available through an explicit control

#### Scenario: Recover an unavailable reader link
- **WHEN** the official reader reports that the book cannot be opened
- **THEN** the app SHALL offer official ebook and web-novel catalog searches, show candidate title and author for user confirmation, and open only a returned official reader link without silently choosing a different edition

#### Scenario: Read the official webpage in full screen
- **WHEN** the user activates full-screen reading using its button or Control-Command-F
- **THEN** the app SHALL enter native window full screen, retain the current skin, decorations, sidebar, toolbars and rounded reading card consistently with local-document reading, preserve the existing web session and page, and provide an exit control
