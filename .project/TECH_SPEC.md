# Lumi Single Project Architecture

## Purpose

Keep the Flutter learning workspace and its Genkit backend in one Dart/Flutter package while preserving the HTTP boundary between the browser UI and backend process.

The approved future web UI refresh is documented in [WEB_UI_REDESIGN.md](plans/WEB_UI_REDESIGN.md). It preserves these ownership boundaries and does not change backend/API behavior.

## Components and ownership

| Component | Location | Owns |
|---|---|---|
| Flutter entry point | `lib/main.dart` | Launches `LumiWebApp` |
| Flutter UI | `lib/ui/` | Workspace composition and independent widget libraries for workspace navigation, editors, settings, coach, canvas, graph, search, and theme |
| Flutter data layer | `lib/data/` | HTTP DTOs and API calls, client-side preference extraction, workspace loading, and ordered note/canvas writes |
| Genkit backend | `bin/server.dart`, `lib/backend/` | Provider selection, agents, routes, local JSON stores, and agent session lifecycle |
| Regression checks | `scripts/`, `test/` | Offline API, workspace, and UI/data contract verification |

## Data flow

1. `lib/main.dart` starts the Flutter app.
2. Workspace UI calls `WorkspaceRepository` for workspace data and writes; settings uses the HTTP client for preferences.
3. `WorkspaceRepository` delegates HTTP operations to `LumiApi` and serializes updates per note/canvas while merging in-flight edits with workspace loads.
4. The coach sends model turns to the Genkit backend's assistant or specialist HTTP endpoints.
5. The backend validates requests, runs Genkit providers/tools, and reads or writes local JSON files under `.data/` by default.
6. Responses return as JSON or Genkit streaming events.

The package is unified, but the browser UI and backend run as separate processes: browser Flutter cannot host the server runtime. Provider credentials and filesystem persistence remain backend-owned.

## Dependency direction

`lib/main.dart -> lib/ui -> lib/data/WorkspaceRepository -> LumiApi -> HTTP -> bin/server.dart -> lib/backend -> Genkit/provider and local persistence`.

The backend does not import Flutter code. The UI does not import backend storage or provider implementation code. Feature widgets live in separate UI libraries and expose public widgets to `app.dart`; each library keeps its implementation helpers private. Genkit's experimental remote client is used only as transport to the backend agent endpoint. Conversation deletion is requested through `LumiApi`, then performed by the backend against the file-backed session snapshots and pointer.

## Acceptance checks

- The repository root contains the only active Flutter package manifest and platform runners.
- Flutter UI is under `lib/ui/`; client HTTP code is under `lib/data/`.
- Workspace API coordination and ordered writes are owned by `WorkspaceRepository`; UI retains presentation, selection, and interaction state.
- UI feature files are independent Dart libraries rather than `part` files of the app shell.
- Genkit server entrypoint is `bin/server.dart`; backend implementation is under `lib/backend/`.
- Root-level Flutter analysis, tests, offline regressions, and web build work with the consolidated package.
