## Why
The user wants the repository and app renamed MaBooks and a reusable skin system inspired by their supplied spring reading interface. Apply the visual language to the working reader rather than producing only a mockup.

## What Changes
- Rename GitHub repository, Swift executable, application title, package and documentation to MaBooks.
- Add four persistent skins with shared palette tokens, backgrounds, panel styles and paragraph highlighting.
- Restyle the native three-column bookshelf, reader and discussions using a warm, spacious spring aesthetic.
- Create an original decorative sakura illustration; never embed the supplied UI screenshot as app UI.
- Preserve storage identifiers and legacy data location so existing books, preferences and Keychain access remain available.

## Capabilities
### New Capabilities
- `reader-skins`: Persistent appearance selection, tone compatibility, decorations and app-wide native palette.
### Modified Capabilities
None. Existing reading and Gateway contracts stay intact.

## Impact
SwiftUI views and packaged resources change; ReaderCore gains a provider-independent skin identifier. Packaging and CI ship MaBooks.app with its resource bundle. No new runtime dependencies or Gateway changes.
