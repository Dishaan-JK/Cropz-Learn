# Lumi settings implementation — 19 October 2026

The approved warm paper and sage design is implemented as eight responsive
Flutter settings sections, with a category rail on desktop and a category picker
on mobile. This report describes working behavior, rather than the original
concept prototype.

## Working behavior

- General: display name, workspace name in the sidebar, next-visit start page.
- Appearance: light/dark/system theme, manual accent or web startup rotation,
  interface text sizing (preserving system text scaling), comfortable/compact
  density, and reduced page/theme animation.
- AI & models: existing backend-owned provider configuration, model discovery,
  masked key entry, separate connection save, and a real provider test action.
  Saving configuration is not described as a successful inference test.
- Learning & coach: teaching style, level and assessment question-count defaults
  accompany new requests; explicit student instructions take priority. Active
  note context is optional. Remembered preferences can be disabled; the backend
  agent tools respect that choice as well as the frontend. Previously sent chat
  context cannot be retracted from an existing conversation.
- Workspace & editor: default editing/preview mode, focused/wide writing width,
  browser writing suggestions, actual autosave delay and recent-chat limit.
- Artifacts & storage: default grid/list and sort order, live counts/disk usage,
  and a downloadable JSON export containing workspace content, full canvas
  assessment marking data, archives, learning records, preferences and images.
  Provider credentials and agent session files are excluded by an explicit
  allowlist.
- Privacy & data: forget an individual preference, confirmation before forgetting
  all preferences, export data, or stage/reset application defaults. Content,
  academic archives and provider configuration are preserved by these controls.
- About & diagnostics: actual service/model/storage data, a content-free and
  credential-free diagnostic report, and package/font licenses. Service health
  and provider inference are explicitly distinguished.

Application preferences are validated in `lib/data/app_settings.dart` and saved
atomically through `lib/backend/app_settings_store.dart`. Concurrent patches are
serialized, failed writes do not update committed in-memory values, and later
writes recover. The UI exposes save/discard/errors. Application drafts survive
navigation within the current app instance. Completing an in-flight save clears
only matching submitted drafts and preserves newer edits.

## Verification

- `./scripts/flutter analyze --no-pub`: no issues.
- `./scripts/flutter test --no-pub`: 49 tests pass, including schema validation,
  concurrent persistence/reload, failed-write recovery, save failure UI,
  save/discard, responsive navigation, editor defaults, actual autosave timing,
  and preserving edits made during an in-flight save.
- `./scripts/dart scripts/workspace_regression.dart`: 24 assertions pass.
- `./scripts/dart --packages=.dart_tool/package_config.json scripts/lumi_api_regression.dart`:
  17 assertions pass.
- `node scripts/settings_api_regression.cjs`: disposable live backend checks
  validate endpoints, rejection of invalid patches, settings/content persistence
  across backend restart, storage counts, complete export including marking keys
  and image bytes, credential exclusion, profile-clear preservation, and CORS.
- `./scripts/flutter build web --no-pub --no-wasm-dry-run`: release build passes.
  An earlier build also passed the Wasm dry run. Flutter emits its existing
  optional Cupertino icon-font warning; the supplied Material/Lucide icons render.
- Headless Chrome checks: all eight sections render and navigate in light and
  dark modes at 1440 px and 390 px; the 1024 px tablet layout also renders.
  A name edit persists through reload, the export button downloads valid JSON,
  and there are no page exceptions or Flutter overflow reports. There are 33
  screenshots in `settings-pages.html`, with machine-readable results in
  `settings-browser-checks.json` and images in `screenshots/settings-*.png`.
  Reproduce with `node scripts/settings_browser_regression.cjs`; provide
  `PLAYWRIGHT_CORE_PATH` if Playwright Core is outside Node's module search path.
  Rebuild the gallery with `python3 scripts/settings_screenshot_gallery.py`.

All mutation and browser checks use disposable directories under `/tmp` and
independent service ports. No user workspace content or real provider credentials
were changed. No live provider inference claim is made by this settings review.

## Explicit version boundaries

Exports are manual data copies; restoration and scheduled backups are unavailable
and labelled accordingly. There is no UI claiming automatic encryption, cloud
synchronization, OS-level scheduled reminders, or whole-workspace erasure.
Browser downloads are supported in the web app; other platforms report an
unsupported download instead of showing a false success.

Restart the backend to enable `/api/application-settings`, `/api/workspace/status`
and `/api/workspace/export`, then serve the updated Flutter web build.
