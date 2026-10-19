# Home navigation and settings save feedback

Implemented 2026-10-19.

## Changes

- Added Home to the full sidebar, medium-width navigation rail, and mobile drawer.
- Home opens the existing welcome page, including with existing notes or while workspace data loads. Added shortcuts to Artifacts, Canvas, Coach and note creation. The existing default startup destination remains Artifacts; Home is also available as an explicit start-page preference.
- The settings footer remains visible instead of disappearing when a successful save clears staged changes.
- Save changes is disabled without edits, becomes Saving… while the request runs, then becomes a disabled Saved button after confirmed success. A new edit restores Save changes. Discard clears pending edits and returns to the idle state.
- Failed saves retain editable pending values and an enabled retry action. Edits made during a save remain pending and do not receive a misleading Saved state.

## Verification

- Static analysis: no issues.
- Full Flutter suite: 73 tests passed.
- Release web build: passed. Existing Cupertino icon-font reference warning remains.
- New Home regression tests navigate from Settings and Canvas to Home with pre-existing notes, then open Artifacts, at widths 390, 1024 and 1440.
- New save-state tests use a delayed HTTP response to observe disabled idle state, enabled dirty state, disabled Saving…, disabled Saved, re-enabled edits, discard, and edits made while saving. Existing failure coverage also verifies that retry remains enabled.
- Responsive sidebar tests verify Home and the continued reachability of Recently created and Folders through scrolling.

Tests use mocked HTTP and Flutter widgets; a live browser session was not inspected for this change. Restart the backend to enable the newly supported Home startup preference and reload the updated client.
