# Page and View Dependency Trees

The app has a single Flutter web entry with in-app view switching rather than URL routes. Trees show repository-local imports; Flutter SDK and package imports are omitted.

## Workspace shell / Notes

Entry: `lib/main.dart` → `lib/ui/app.dart`

- `lib/ui/app.dart`
  - `lib/data/lumi_api.dart`
  - `lib/data/workspace_repository.dart`
    - `lib/data/lumi_api.dart`
  - `lib/ui/coach_panel.dart`
  - `lib/ui/learning_views.dart`
  - `lib/ui/lumi_theme.dart`
  - `lib/ui/note_editor.dart`
  - `lib/ui/settings_page.dart`
  - `lib/ui/workspace_widgets.dart`
    - `lib/data/lumi_api.dart`
    - `lib/ui/lumi_theme.dart`

## Search

Entry: `SearchResults` in `lib/ui/learning_views.dart`; selected by `lib/ui/app.dart`.

- `lib/ui/learning_views.dart`
  - `lib/data/lumi_api.dart`

## Canvas and Knowledge Graph

Entry: `CanvasView` and `KnowledgeGraph` in `lib/ui/learning_views.dart`; selected by `lib/ui/app.dart`.

- `lib/ui/learning_views.dart`
  - `lib/data/lumi_api.dart`

## Note Editor

Entry: `NoteEditor` in `lib/ui/note_editor.dart`; selected by `lib/ui/app.dart`.

- `lib/ui/note_editor.dart`
  - `lib/data/lumi_api.dart`

## Lumi Coach

Entry: `CoachPanel` in `lib/ui/coach_panel.dart`; composed by `lib/ui/app.dart`.

- `lib/ui/coach_panel.dart`
  - `lib/data/lumi_api.dart`
  - `lib/data/user_preferences.dart`

## Settings

Entry: `SettingsPage` in `lib/ui/settings_page.dart`; selected by `lib/ui/app.dart`.

- `lib/ui/settings_page.dart`
  - `lib/data/lumi_api.dart`
  - `lib/data/user_preferences.dart`
