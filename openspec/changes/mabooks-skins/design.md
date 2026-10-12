## Context
The working scaffold has three columns and native themes. Reference artwork shows an ivory translucent workspace, blush selection, serif prose, portrait book thumbnails and spacious paragraph comments.

## Goals / Non-Goals
Goals: a working MaBooks app; spring design; persistent skin switching without resetting reading state; correct resource packaging; backward-compatible user data.
Non-goals: invented likes or social posting controls, fake chapter metadata, new book formats, replacing official WeRead webpage appearance.

## Decisions
- ReaderSkin is a Codable stable enum in ReaderCore. SwiftUI SkinPalette translates it and the existing ReaderTheme into color tokens and decoration choices.
- Appearance is injected through SwiftUI Environment so sidebar, native reader, discussions and settings use the same palette. Skin and reading tone remain independent.
- A dedicated skin sheet offers visual previews, an explicit selected state, optional decorations and tone controls. @AppStorage persists selections immediately.
- Generate an original spring background from the user's reference mood; render all UI as real SwiftUI views. Do not include the user's screenshot in the public repository.
- Original illustration is bundled via SwiftPM resources and copied into .app/Contents/Resources during packaging.
- Keep com.mariomlll.wereadmac identity, Keychain service and WeReadMac application-support path for compatibility. Rename visible and build product names. A later identity migration must handle WebKit/Keychain/UserDefaults explicitly.
- Native header and sidebar contain functional reading, appearance, import and account controls. Avoid reference controls for unimplemented notes, likes and commenting.

## Risks / Trade-offs
- Decorative background reducing readability → opaque-enough ivory/dark reading surfaces, generous line height, optional decoration toggle and plain paper skin.
- App rename breaking Bundle.module → package resource bundle alongside executable and verify in the packaged app.
- Platform identity retains old technical name → document it as intentional compatibility, not visible branding.

## Migration Plan
Rename existing remote repository (GitHub redirects old URL), update origin, ship MaBooks executable and app. Existing on-disk user data remains at the same location. No deletes or credential migration.
