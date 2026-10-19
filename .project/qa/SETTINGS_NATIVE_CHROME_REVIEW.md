# Native Chrome Computer Use review — 19 October 2026

Opened the release web app in a visible Google Chrome window using the
computer-use-linux plugin. Inspection used native screenshots, pointer clicks,
window-title double clicks, an edge drag to narrow the browser, and native wheel
scrolling. This is separate from the earlier headless browser checks.

## Confirmed through the visible UI

- Artifacts library renders the seeded note and canvas, in light and dark themes.
- All eight settings categories open and display their expected content.
- The theme dropdown opens; selecting Evening sage stages one change; Save changes
  applies the dark theme and shows the saved confirmation.
- Reloading Chrome retains the dark theme. The enabled startup accent rotation
  advances the accent from sage to blue, as expected.
- A native edge drag narrows the Chrome window to 526 logical pixels. The app
  changes to a mobile-style header and settings category picker. The picker opens,
  selecting Appearance works, and the content scrolls to Reading comfort while
  the category navigation remains accessible.
- The narrow workspace drawer opens and scrolls independently. It shows recent
  note/canvas entries and Biology → Cells → Cell structure, plus the canvas tree.
  Selecting the Cell structure note opens its editor and closes the drawer.
- Service diagnostics show Online, local Ollama and the configured model. No AI
  generation or provider-test action was executed.

## Corrections made and rechecked in Chrome

Storage summaries now use singular labels for one object and report bytes/KB for
small workspaces. After rebuilding and reloading the visible browser, the page
shows **1 note**, **1 canvas**, **2 folders**, **2 artifacts**, and **1.9 KB on disk**.

After these text-display changes:
- Flutter analysis: no issues.
- Focused settings UI tests: 3 pass.
- Release web build: passes.
- The preceding full implementation suite remains recorded as 49 passing tests.

## Limits of this check

Chrome exposed no AT-SPI accessibility tree even when launched with forced
renderer accessibility. Inspection therefore used observed screenshot coordinates.
Native text-field focus was visible, but the native text-input call did not produce
visible text; keyboard text-entry correctness is **unverified by Computer Use**.
The earlier Flutter tests and headless browser checks provide separate text/save
coverage and are not counted as native keyboard proof here.

The KWin resize-window API reported unsupported; resizing was verified using a
native window-edge drag. Two coordinate clicks were paused by automatic review;
fresh screenshots identified the read-only navigation targets, and subsequent
explicitly targeted clicks succeeded. No blocked action remains outstanding.

## Review environment and evidence

The real user workspace and provider credentials were not used or modified.
The review uses `/tmp/lumi-cua-review-u0tr9rs_`, a separate Chrome profile under
`/tmp/lumi-cua-chrome-profile`, and local services at `127.0.0.1:5000` (web) and
`127.0.0.1:8080` (backend). Chrome remains open on the review workspace.

Native screenshots:
- `screenshots/native-settings-dark.jpg`
- `screenshots/native-settings-mobile.jpg`
- `screenshots/native-settings-storage-final.jpg`
