## ADDED Requirements

### Requirement: Persistent skin selection
MaBooks SHALL offer sakura, ocean, forest and paper skins with stable identifiers and an explicit selection state. Selection SHALL persist after restart without changing the selected book, paragraph, reader layout or font size.

#### Scenario: Switch skin during reading
- **WHEN** a user selects another skin
- **THEN** native panels and highlights SHALL immediately adopt the new palette and reading selection SHALL remain unchanged

#### Scenario: Restart
- **WHEN** the app restarts after choosing a skin
- **THEN** the same skin and decoration preference SHALL be restored

### Requirement: Shared appearance
The bookshelf, native reader, paragraph panel and account settings SHALL share appearance tokens. Reading tone SHALL be independent from skin and optional artwork SHALL not prevent reading or interaction.

#### Scenario: Night reading
- **WHEN** a user selects night tone with the sakura skin
- **THEN** the reading surface SHALL be dark while skin selection remains sakura

### Requirement: MaBooks branding and compatibility
The public repository and visible app product SHALL be named MaBooks. Existing local books, paragraph locations and credentials SHALL remain accessible through stable storage identifiers.

#### Scenario: Open the renamed app
- **WHEN** a user launches MaBooks.app after using the original app
- **THEN** the app SHALL show MaBooks branding and SHALL load the existing library and preferences
