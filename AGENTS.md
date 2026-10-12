# Project guidance

This repository is a native SwiftUI macOS app, minimum macOS 14. Read README.md and the active OpenSpec change before implementation.

- ReaderCore owns provider-independent book, paragraph and anchor models.
- WeReadKit owns the official Tencent Agent Gateway and response mapping.
- WeReadMac owns UI, local persistence, Keychain and WebKit.
- Preserve server ranges as opaque values. Match comments with bookID + chapterUID + range.
- Do not invent private WeRead endpoints, full-text extraction or reader URLs. Consult Tencent's official docs linked in README before changing the adapter.
- Keep fixtures synthetic and never commit API keys, cookies, personal shelves or copyrighted book files.
- Account errors must not silently switch to sample content; label demo content explicitly.
- Run `bash scripts/test.sh` and `bash scripts/package-app.sh` for changes affecting app or integration. Use `openspec validate <change> --strict` for changed specs.
- Keep account-backed acceptance separate from offline fixtures; update docs/ACCEPTANCE.md only with checks actually performed.
- Use `codex/` branch names for future feature work.
