## ADDED Requirements

### Requirement: Local reading workspace
The app SHALL provide a labelled sample book and UTF-8 TXT import with persistent paragraphs and reading position.

#### Scenario: Import and reopen
- **WHEN** a user imports a UTF-8 TXT book and selects a paragraph
- **THEN** the book and selected location SHALL be available after restarting

### Requirement: Display options
The native reader SHALL offer light, sepia, dark and system themes; scrolling, viewport pagination and focus modes; font size controls. These controls SHALL be explicitly scoped to native reading.

#### Scenario: Read in paginated mode
- **WHEN** the user opens an imported book in the default paginated mode
- **THEN** the reader SHALL fit text to the available page width, height and font size, including splitting long paragraphs, with bounded previous/next buttons, page-edge clicks and keyboard navigation

#### Scenario: Repaginate and reopen
- **WHEN** the window or font size changes, or a local book is reopened
- **THEN** the reader SHALL preserve the paragraph and UTF-16 text position and show the page containing that position without missing or repeating text

### Requirement: Paragraph discussions
The reader SHALL open a side panel when a paragraph is selected, show its quoted text, and distinguish sample discussions from remote discussions.

#### Scenario: Sample selection
- **WHEN** the user selects a sample paragraph
- **THEN** its sample comments SHALL appear with an explicit sample label

### Requirement: Collapsible navigation sidebar
The app SHALL provide a sidebar toggle in the sidebar title row, an expand control in the reading header when collapsed, and a Command-Option-S shortcut for both local and official-web reading, including full screen.

#### Scenario: Collapse and expand
- **WHEN** the user toggles the sidebar
- **THEN** the sidebar SHALL collapse or expand without reloading the web page or changing the selected book, the expanded/collapsed preference SHALL persist, and the reading area SHALL use the available width

#### Scenario: Expand from native focus mode
- **WHEN** the user expands the sidebar while native focus mode hides it
- **THEN** the reader SHALL return to paginated mode and show the sidebar

### Requirement: Large local books and recoverable deletion
The app SHALL support UTF-8 TXT imports up to 100 MiB, perform file reading and archive writing off the UI thread, and preserve legacy library data.

#### Scenario: Import at the size limit
- **WHEN** the user imports a UTF-8 TXT at or below 100 MiB
- **THEN** the book SHALL be imported and saved, while larger files SHALL produce a clear size-limit error

#### Scenario: Delete and restore a local book
- **WHEN** a user deletes a local book through its header or context menu
- **THEN** the book SHALL move to a persistent recently-deleted collection, its original source file SHALL remain unchanged, and restoring SHALL retain its book identity, text and reading position
