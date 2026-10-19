# Artifact library validation — 19 October 2026

## Automated evidence

- `./scripts/flutter analyze --no-pub`: no issues.
- `./scripts/flutter test --no-pub`: 30 passed. Includes archive deduplication,
  durable reload, regenerated answers, backend session persistence and source
  conversation deletion, history backfill, concurrent archive writes, full-text
  search, empty/error/retry behavior, and responsive library/reader checks at
  390/700/1180 logical pixels in both themes. Existing shell tests also pass.
- `./scripts/dart scripts/workspace_regression.dart`: 24 assertions passed.
- `./scripts/dart --packages=.dart_tool/package_config.json scripts/lumi_api_regression.dart`:
  17 assertions passed.
- Release web build passed with review backend at 127.0.0.1:8082. Flutter reports
  a missing optional Cupertino icon font; no Cupertino icons are used here.
- Live HTTP using disposable `/tmp/lumi-professional-review` data: existing
  library listed; note creation indexed; update reflected in archived text;
  source deletion retained the full archived text.

## Architecture and behavior review

- UI remains in lib/ui, HTTP DTO/client in lib/data, persistence in lib/backend.
- Archive is stored separately from live notes, canvases and agent history.
- Session-store hook captures completed backend replies without a browser callback.
- System, user, tool messages and tool-call text are excluded from response capture.
- Writes serialize mutation with atomic temp-file replacement; archive has no
  history cap. Replay deduplication uses session/message position plus SHA-256
  of content. Distinct regenerated replies remain separate objects.
- Notes/canvases retain their latest snapshot; archive entries survive source
  deletion. Source navigation only appears when that source still exists.
- Attachment cleanup includes archive references to avoid breaking archived images.
- Existing saved appearance preference and web accent cycle are preserved.

## Browser review

The Chrome MCP tool failed with `Missing X server to start the headful browser`.
A separate headless Chrome run using installed Playwright Core and Google Chrome
successfully loaded the fresh release build. Fixtures are disposable academic
examples, not the user's workspace data. Saved screenshots live in screenshots/.

Provider generation was not exercised. Deterministic session-store tests prove
capture at the backend persistence boundary; they do not prove live provider
quality, classification accuracy, or completion.

Final headless Chrome checks passed:
- Full-content search for mitochondrion selects the flashcard material.
- Flashcard reader opens with Copy text; closes predictably.
- List view opens a note and Open in workspace reaches the real note editor.
- Mobile drawer returns to Artifacts in light and dark modes.
- Fresh screenshots at 1440×1000, 1024×1000 and 390×844 in both modes.
- No page errors in any of the six browser runs.

Screenshots visually reviewed: desktop light, desktop dark, narrow light, medium
light, and the artifact reader. Horizontally scrollable type filters are deliberate;
the page itself does not overflow. All counts reflect disposable fixture data.

Final visual refinement: rail selection now explicitly highlights only the active
destination, and the sidebar only highlights a recent note while editing notes.
The six shell/navigation tests pass after this refinement. Screenshots precede
this small selection-state correction; library layout/content are unchanged.
Temporary review backend and web-server processes were stopped after validation.

Final production build: `./scripts/flutter build web --no-pub` passed with the
normal `http://127.0.0.1:8080` service address restored. Final analysis after
navigation refinement reports no issues. Formatting completed successfully.
