## ADDED Requirements

### Requirement: Local reading workspace
The app SHALL provide a labelled sample book and UTF-8 TXT import with persistent paragraphs and reading position.

#### Scenario: Import and reopen
- **WHEN** a user imports a UTF-8 TXT book and selects a paragraph
- **THEN** the book and selected location SHALL be available after restarting

### Requirement: Display options
The native reader SHALL offer light, sepia, dark and system themes; scrolling, grouped pagination and focus modes; font size controls. These controls SHALL be explicitly scoped to native reading.

#### Scenario: Read in paginated mode
- **WHEN** the user selects grouped pagination
- **THEN** the reader SHALL show up to four paragraphs per page with bounded previous/next navigation

### Requirement: Paragraph discussions
The reader SHALL open a side panel when a paragraph is selected, show its quoted text, and distinguish sample discussions from remote discussions.

#### Scenario: Sample selection
- **WHEN** the user selects a sample paragraph
- **THEN** its sample comments SHALL appear with an explicit sample label
