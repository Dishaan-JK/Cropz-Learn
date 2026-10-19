# Lumi parity implementation and verification

## Scope

This review tracks the documented feature gaps in the consolidated Lumi Flutter project against the prior Cropz-Learn requirements. The UI and local Genkit backend now live in one Dart package, with a deliberate HTTP boundary between the browser and backend process. This is source and static verification; it does not establish full provider-backed end-to-end parity.

## Documented gaps and current implementation

| Area | Implemented behavior | Remaining evidence limit |
|---|---|---|
| Nested folders | Create and browse child folders, navigate ancestors, and include descendant notes in folder views. | Chrome interaction proof is limited to screenshots and source review. |
| Canvas | Persist card positions and note connections; drag cards; pan, zoom, and reset; select up to 30 notes when creating a canvas. | Interactive canvas operations were not exercised through the available browser automation. |
| Knowledge graph | Force-directed layout, draggable/openable note cards, editable `[[Title]]` backlinks, directed arrows, and duplicate/ambiguous reference handling. | Graph interaction was not exercised through the available browser automation. |
| Markdown editor | Markdown preview for headings, emphasis, inline code, note links, images, code, quotes, lists, tables, and math; slash insertion menu; image upload and storage validation. | Preview, slash menu, and image picker/upload were not exercised in Chrome. |
| Editor recovery | Debounced server saves, ordered per-note writes, local draft recovery, and save retry behavior. | Network failure recovery was reviewed in code, not exercised end to end. |
| Coach conversations | Genkit file-backed sessions, restored by the browser per assistant/specialist route. | A live model turn and restore cycle were not verified against an active provider. |
| Conversation cleanup | Confirmed “Start a new conversation” deletes the selected coach’s saved session snapshots and pointer, then clears its browser session key. | Chrome reviewer is checking the latest dialog presentation; deletion was not exercised against real session data. |
| UI library boundaries and workspace data ownership | Feature widgets live in independent libraries with explicit imports; `app.dart` composes public widgets. `WorkspaceRepository` owns workspace API coordination and ordered note/canvas writes. | `LumiWorkspace` still owns presentation, selection, and interaction state. Concurrent load/write behavior is code-reviewed; live backend race behavior was not exercised. |

## Checks completed for this implementation

- `./scripts/flutter analyze --no-pub` — passed, no issues after the follow-up changes.
- `./scripts/flutter build web --no-pub` — passed; production web bundle built in `build/web` after the follow-up changes.
- ECC architecture review — no blockers in session cleanup, independent widget libraries, or workspace repository ownership. Review identified and then verified a fix for stale overlapping loads; per-entity write queues and deletion tombstones also preserve writes/deletes across active loads. Residual risks: deleting a session scans all session JSON files and malformed snapshots are skipped.
- ECC Chrome UI review — desktop workspace/editor rendered cleanly: navigation, folder/recent-note lists, title/body editor, toolbar, and Preview control fit without clipping; save labels were visible. The reviewer did not edit the existing note. The running server had stopped, so Chrome showed an already-loaded build and could not verify the latest source revision. Earlier narrow viewport and coach confirmation dialog checks remain as recorded above. Other feature interactions remain unverified.
- No automated tests were run during this implementation pass.

## Remaining verification limits

- Local model or external provider inference, tool calls, specialist delegation, and persisted session restoration have not been exercised with a live model.
- Formal Flutter tests and offline regression scripts were not rerun during this implementation pass.
- Browser interactions for nested folders, canvas, graph, editor preview/slash menu/image upload, and coach session restoration remain unverified in the available Chrome setup.
- Previously reported backend image validation limits file type and size and rejects malformed or multi-frame images. The implementation should continue to be reviewed if animated-image support is added.
- A clear path now exists for sessions whose IDs are stored by the browser. Interrupted first turns or damaged snapshot files may leave untracked files under `.data/agent-sessions`.

## Readiness

The requested feature gaps are implemented in source, the analyzer and production web build pass, and the architecture reviewer found no blocking structural issue in the completed areas. Feature parity is not yet fully demonstrated: live provider behavior and browser interaction flows still need an environment capable of exercising them.
