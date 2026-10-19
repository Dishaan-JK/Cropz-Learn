# Lumi Web UI Redesign Progress

Plan: [WEB_UI_REDESIGN.md](WEB_UI_REDESIGN.md)

## Implemented

- **Theme foundation:** Warm paper, warm white, deep ink, muted surfaces and borders; coordinated light/dark modes; selected accent palette; bundled DM Sans and Lora font assets and SIL OFL licenses; Lucide outline icons.
- **Persistent appearance:** Light remains the default; theme choice is stored locally. Web startup rotates Sage, Blue, Light orange, and Maroon independently from the saved theme.
- **Responsive shell:** Full sidebar at 1280px+, compact navigation rail at 768–1279px, and navigation drawer below 768px. Coach presents as a side panel on wide screens and overlay on narrower screens.
- **Workspace screens:** Shared typography, colors, cards, iconography, controls, and spacing applied to editor/preview, navigation, search and empty/error states, Canvas, Graph, Coach, and all Settings tabs. Existing workspace APIs, routes, repository ownership, and content workflows are preserved.
- **Browser boundary:** Appearance/session storage and image selection use conditional platform adapters so VM widget tests can exercise the UI without importing browser-only libraries.
- **Responsive fixes:** Drawer header fit, list tile ink surfaces, Coach header controls, and mobile Coach width were checked and corrected through widget testing.

## Verification

- `./scripts/flutter test --no-pub`: passed, including the existing data/API tests and new widget checks for wide, medium, and narrow shell layout; drawer navigation; Coach open/close; all four Settings tabs; warm light/dark palette.
- `./scripts/flutter build web --no-pub`: passed.
- `./scripts/flutter analyze --no-pub`: no errors or warnings; one existing style info remains in `bin/server.dart:1072`.
- Chrome screenshots were reviewed at 1440×1000, 1024×768, and 390×844 in light mode, and 1440×1000 in dark mode. A second pass used an isolated `/tmp` backend with synthetic data to review populated Notes, Canvas, Graph, Coach, and all four Settings tabs. The populated pass exposed inherited borders on the editor fields and a graph layout that began too far from the visible area; both were corrected. In headed Chrome, dark theme persisted across a full browser process restart and accent rotation was observed at startup. A later Computer Use pass exposed and fixed New note routing from Settings and missing retry loading feedback. Provider requests, editor autosave after text edits, and keyboard traversal remain unverified. See the [QA record](../qa/WEB_UI_REDESIGN.md) and its screenshot captures.

## Implementation note

The planned `google_fonts` package at 6.3.0 failed to compile under the repository’s Flutter/Dart toolchain in the VM widget runner. The selected fonts are therefore registered directly as local Flutter font assets in `pubspec.yaml`; this keeps them offline-capable and avoids runtime font fetching. Lucide is pinned at 3.1.25.

## Remaining review

- Confirm high contrast, keyboard traversal, and title/body text entry in the note editor. The headed Chrome pass was inconclusive for these controls because the Flutter page exposed no AT-SPI nodes and desktop text dispatch was not reflected in the editor fields. See the [QA record](../qa/WEB_UI_REDESIGN.md).
