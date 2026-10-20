# Lumi React migration

## Objective and architecture

Complete the Lumi browser experience in React + TypeScript while retaining the
existing Dart/Genkit HTTP service and local stores as the source of truth.

```text
React shell -> feature screens -> typed service/query layer -> same-origin /api
                                                        -> Dart/Genkit service
                                                        -> provider tools + local stores
```

Use TanStack Query for remote/cache state. Keep transient view, editor draft,
dialog, selection, and practice state inside the smallest owning feature. Keep
API DTOs and requests in `src/lib`; keep presentation grouped by feature under
`src/features`; keep shell/navigation and app composition under `src/app`.
Provider credentials, workspace files, agent tools, and answer keys remain on
the Dart backend.

## Existing Lumi parity surface

- [x] Workspace shell, recent notes, note create/edit/autosave, and note search.
- [x] Persistent Artifacts library, filters, detail reading, flashcards, quiz scoring.
- [x] Notes and folder management: note create/edit/autosave/move/delete; nested folder trees, collapse/expand, parent selection, and reparenting with descendant-cycle prevention.
- [x] Canvas: create canvases, attach/detach notes after creation, edit title/description, persist card positions, and apply saved canvas pattern/colors. Existing-board editing is backed by validated Dart service updates.
- [x] Graph: load and render note nodes and backend edges; selection and open-related-note behavior.
- [x] Home: live workspace summary, recent notes, and navigation actions.
- [x] Coach: the React drawer streams every turn through the central `/api/assistant` orchestrator; the backend selects/delegates to Teacher, Connections, Tester, and Progress Reviewer as needed. Context snapshot restore, new/delete session actions, and a local recent-session list are supported. Direct specialist routes were separately exercised during earlier integration checks; users no longer select a specialist in the drawer.
- [x] Settings: General, Appearance, Learning & coach, Workspace & editor, Artifacts, AI & models, Privacy & data, Artifacts & storage, Diagnostics, and Hardware report are implemented. The saved start page drives initial routing, provider secrets remain transient in the UI and excluded from query state, and hardware detection is distinguished from runtime verification.
- [x] Privacy/data: profile review/add/remove/clear, learning-record counts/clear, safe export, and confirmation-gated import are implemented and verified end-to-end against disposable data.
- [x] Attachments and note markdown/media rendering: safe Markdown preview with tables, clickable wiki-style note references, inline and block KaTeX math, and image upload/embedding are implemented and browser-verified. KaTeX and its CSS are lazy-loaded only when math is present.

## Acceptance evidence

- Every listed feature is accessible and connected to its existing backend contract.
- Service state uses TanStack Query with stable keys, invalidation, retries/errors,
  and mutations; local interactive state is not duplicated into the server cache.
- Provider credentials and private answer keys never enter browser responses/state.
- Lint, focused component tests, TypeScript production build, and fresh Chrome
  computer-use end-to-end checks cover primary flows and wide/medium/narrow layouts.
- The full-stack launcher starts/reuses the Dart backend and Vite proxy without
  duplicate backend processes.

## Remaining implementation order

1. Reconcile any remaining parity gaps and maintain this record as the implementation changes.

## Current evidence (2026-10-20)

- [x] React production build, Oxlint, and 24 Vitest cases pass after feature modularization, lazy math rendering, saved start-page routing, and all five Coach SSE endpoint contracts.
- [x] Fresh isolated Chrome window opened against Vite; Chrome created and autosaved a note to the disposable Dart backend.
- [x] Artifacts and Canvas screens loaded in Chrome; Canvas created with the saved note linked. Backend readback confirmed both records.
- [x] Graph screen loaded with the persisted note node and linked-note behavior is implemented.
- [x] Local Ollama-backed Coach turn completed through React UI; Dart/Genkit stream, tool calls, session snapshot, and generated artifact were read back from disposable backend storage.
- [x] In a fresh Chrome session, diagnostics reported the disposable Dart backend online; the UI completed a live Ollama connection/model-access check.
- [x] Fresh Chrome exercised hardware inventory (Intel graphics detected; runtime not verified), Appearance preference save (dark mode visibly applied), and workspace export (download completed; UI stated credentials excluded).
- [x] Privacy & data preference flow explains the backend's explicit-preference rule, displays validation errors, and Chrome verified accepted add/read/remove against the disposable backend.
- [x] Existing Canvas title edit and note unlink/relink completed in fresh Chrome; a GET readback from the disposable Dart service confirmed the updated title and attached note.
- [x] In Chrome, a Markdown table rendered as a semantic table and a wiki-style note reference opened the target note; GET `/api/notes` confirmed the source Markdown persisted in the disposable backend.
- [x] In a separate fresh Chrome profile, the expanded E2E runner uploaded an image through the React file input, fetched and rendered the backend attachment, compared the Artifacts library with the API and opened an artifact, and passed 1440/900/390px layout checks including the mobile navigation drawer.
- [x] The same Chrome run saved Appearance density through the UI and verified it after reload and via `/api/application-settings`; it exercised export, canceled import without replacing data, accepted a same-workspace import, and tested both confirmation-gated privacy clears with backend readback.
- [x] The same Chrome run rendered inline and block KaTeX math on demand; the production build keeps the initial JS at 336.15 KB (101.01 KB gzip) and splits the 259.19 KB KaTeX renderer into a separate chunk (77.75 KB gzip).
- [x] Chrome saved the General start page as Notes, reloaded, and opened Notes from the persisted setting; explicit navigation remained in control during the same app session.
- [x] All five live Coach routes returned responses in the fresh Chrome session via the configured local Ollama/Genkit backend; the first cold model response took longer than 60 seconds, so the E2E runner now allows for local CPU inference latency.
- [x] Dart analysis of the changed store/route/regression files is clean; workspace regression passes 24 assertions and API regression passes 17 assertions.
- [x] No planned parity or end-to-end gates remain; recent-session selection is browser-local while conversation transcripts remain persisted by the Dart service.
