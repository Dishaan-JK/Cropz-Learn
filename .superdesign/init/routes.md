# Routes and Views

This is a Flutter web app with one `MaterialApp` home; it does not use URL-based page routing. `LumiWorkspace` switches the main content through `_workspaceView` in `lib/ui/app.dart`. Current destinations are Notes, Search, Canvas, Graph, and Settings; Lumi Coach is a responsive companion panel/drawer.

## View map

| Destination | Widget | Source |
|---|---|---|
| Notes/editor | `NoteEditor` / `WorkspaceWelcome` | `lib/ui/note_editor.dart`, `lib/ui/learning_views.dart` |
| Search | `SearchResults` | `lib/ui/learning_views.dart` |
| Canvas | `CanvasView` | `lib/ui/learning_views.dart` |
| Knowledge graph | `KnowledgeGraph` | `lib/ui/learning_views.dart` |
| Lumi Coach | `CoachPanel` | `lib/ui/coach_panel.dart` |
| Settings | `SettingsPage` | `lib/ui/settings_page.dart` |

The root entry point is `lib/main.dart`, which launches `LumiWebApp`. There is no router configuration file.
