# Web UI Redesign QA Record

**Revision reviewed:** Local build produced 2026-10-16, including navigation and retry fixes.  
**Build target:** Flutter Web; production build plus headed Chrome Computer Use review.

## Results

| Check | Result |
|---|---|
| Existing regression tests and new UI widget tests | Passed during the initial implementation review: `./scripts/flutter test --no-pub`. Not rerun after the two visual-only fixes below. |
| Web production build | Passed: `./scripts/flutter build web --no-pub` |
| Static analysis | Initial implementation review found no errors or warnings. One existing style info remains at `bin/server.dart:1072`; analysis was not rerun after the visual-only fixes. |
| Responsive shell | Reviewed at 1440×1000, 1024×768, and 390×844; no clipping in the captured welcome/error state. |
| Dark theme | Reviewed at 1440×1000; surfaces, text, selected state, and error state remain legible in the captured welcome/error state. |
| Navigation and core layout | Widget checks cover wide sidebar, medium rail, narrow drawer, drawer selection, Coach open/close overlay, and all four Settings tabs. |
| Populated Notes, Canvas, and Graph | Reviewed in Chrome at 1440×1000 with three synthetic notes and two links. The title/body fields are now borderless; graph nodes begin within the visible workspace. |
| Settings | Captured General, AI connection, Personalization, and About in light mode at 1440×1000. Appearance controls and all four tab contents render. |
| Appearance persistence and accent cycle | Dark preference remained dark across a page reload and a full Chrome process restart using the same profile. Accent changed across app starts, including after the browser restart. Restored the page to the light theme afterward. |
| Headed Chrome review (2026-10-16) | Opened `http://127.0.0.1:5000` in Chrome. Settings loaded, light/dark appearance toggled, dark preference survived full process restart, and the accent rotated on startup. The browser was returned to Settings in light mode. |
| Navigation and data loading (2026-10-16) | In Chrome on the isolated build, All notes, Canvas, Knowledge graph, Settings, Search results, and result selection responded. Empty Canvas/Graph states rendered. A disposable note appeared in search and reopened from its result. Stopping the backend produced the service banner; restarting it and choosing Retry restored the workspace note. |
| Defect: New note routing | Reproduced by choosing New note from Settings: the note was created and selected, while Settings remained visible. Fixed `_createNote` to switch to Notes. Rebuilt and verified New note opens the editor from Settings. Canvas and Graph use the same handler, so the route change applies there as well (not separately clicked after the fix). |
| Defect: Retry feedback | Source review found that Retry reused `_load` without setting the loading state, leaving stale content visible during a slow retry. Added a retry-specific loading state while preserving nonblocking background refreshes. The offline/restart/Retry flow recovered in Chrome; the local response was too fast to visually capture the intermediate spinner. |
| Test setup finding: alternate web origin | The first backend launch rejected the app served from port 5001 because the backend default allows port 5000. Restarting with `WEB_ORIGIN=http://127.0.0.1:5001` resolved this test setup mismatch; no CORS code change was needed. |
| Keyboard/focus traversal | Attempted in headed Chrome. Chrome/Flutter exposed an empty AT-SPI tree, so the focused control could not be identified reliably; traversal of the appearance switch remains unverified. |
| Web build after navigation/loading fixes | Passed: `./scripts/flutter build web --no-pub --dart-define=LUMI_SERVICE_URL=http://127.0.0.1:8081`. |

## Captures

- [Light, wide 1440×1000](screenshots/web-ui-light-1440.png)
- [Light, medium 1024×768](screenshots/web-ui-light-1024.png)
- [Light, narrow 390×844](screenshots/web-ui-light-390.png)
- [Dark, wide 1440×1000](screenshots/web-ui-dark-1440.png)
- [Populated Notes, light](screenshots/web-ui-notes-populated-light-1440.png)
- [Populated Canvas, light](screenshots/web-ui-canvas-populated-light-1440.png)
- [Populated Graph, light](screenshots/web-ui-graph-populated-light-1440.png)
- [Coach, light](screenshots/web-ui-coach-light-1440.png)
- [Settings: General](screenshots/web-ui-settings-general-light-1440.png)
- [Settings: AI connection](screenshots/web-ui-settings-ai-light-1440.png)
- [Settings: Personalization](screenshots/web-ui-settings-personalization-light-1440.png)
- [Settings: About](screenshots/web-ui-settings-about-light-1440.png)
- [Populated Notes, dark](screenshots/web-ui-notes-populated-dark-1440.png)

## Limits

Populated screen captures used a temporary backend data directory under `/tmp` containing only synthetic learning notes, folder names, and a canvas. They do not represent or modify the user's `.data` store. The Ollama configuration rendered in Settings is local test configuration; a successful provider request, editor autosave confirmation, and live Coach response were not exercised. These UI captures show loading and populated states, not full feature integration.

The headed browser review used the same user Chrome profile, while the web server and Lumi backend used a disposable workspace under `/tmp`; the user's `.data` store was not opened. Chrome's Flutter page returned no AT-SPI nodes, so keyboard focus targets could not be verified. Text entry in the editor title/body was not confirmed by the available desktop input route; search-field entry was confirmed. High contrast remains unchecked. The fixes are limited to UI state in `lib/ui/app.dart`; no backend, API, note schema, or repository contracts changed.

**Follow-up (2026-10-16):** The earlier browser inventory/DevTools attempt could not start a headful browser. Direct desktop Chrome was later used for theme restart persistence and then this navigation/loading pass. Two UI defects were fixed in `lib/ui/app.dart`: New note now routes to its editor, and Retry restores visible loading feedback. Build passed with the disposable backend URL. Keyboard traversal and editor title/body text entry remain unverified due the available Chrome accessibility/input path; the local backend responds too quickly to capture the retry spinner mid-request.
