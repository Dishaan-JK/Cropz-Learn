# Canvas appearance

Implemented 2026-10-19.

## Behavior

- The Canvas has a subtle 24-unit dot grid by default, with square grid and plain alternatives.
- Pattern painting covers the visible viewport, including beyond board boundaries. It uses the same transformation controller as the board, so dots/lines track pan and zoom without painting the whole extended board.
- Empty and populated canvases share the same appearance preferences. Note cards, quizzes, and controls retain their themed surfaces.
- Settings → Appearance → Canvas provides background pattern, light/dark palette selection, background/pattern colour swatches, exact #RRGGBB entry, a staged preview, and reset to defaults.
- Save changes commits preferences through the existing settings API and backend JSON store. Discard restores saved values. Light and dark colours persist independently. Older preferences receive compatible defaults without migration.
- Shared preferences reject invalid hex colours and unsupported patterns before persistence.

## Verification

- `./scripts/flutter analyze --no-pub`: no issues.
- `./scripts/dart --suppress-analytics analyze`: no issues.
- `./scripts/flutter test --no-pub`: 68 tests passed.
- Canvas tests exercise both themes at widths 390 and 1180, saved appearance consumption, card selection/drag save, pan, zoom and reset. Optional screenshots are generated with `LUMI_CAPTURE_CANVAS=1 ./scripts/flutter test --no-pub test/ui/canvas_appearance_test.dart` under build/canvas-review/.
- Settings tests exercise both 390 and 1440 widths, staged previews, custom hex saves, rejection of invalid colours, discard, and swatch selection. Store tests verify dark-palette persistence and legacy default merging.
- `./scripts/flutter build web --release --no-pub`: passed. The build still reports the Cupertino font reference warning also observed before this change.
- Rendered Canvas widget captures reviewed for background/card layout and pattern coverage. This is Flutter widget rendering, not a live browser inspection.

## Tool boundary

The Superdesign CLI preflight and existing settings-draft retrieval succeeded. Automatic approval review rejected the optional edited-HTML upload and remote-draft mutation because the request did not authorize external disclosure of workspace design content. No remote design was changed. The feature is implemented and verified locally.

Restart the backend to load validation/defaults for the new settings, then reload the rebuilt client.
