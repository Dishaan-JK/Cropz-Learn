# Extractable UI Components

The source widgets are Flutter implementations and cannot be uploaded directly as Superdesign components. If shared HTML components are needed for visual consistency across the concept drafts, convert these source layouts to the Superdesign Petite-Vue template format first. Preserve current labels and interaction affordances.

## Layout components

- `WorkspaceSidebar` — Source: `lib/ui/workspace_widgets.dart`; category: layout; brand, create/search controls, destination navigation, folders, recent notes, settings/theme controls. State props: active view, selected folder/note, current search mode; current note/folder data and callbacks.
- `WorkspaceTopBar` — Source: `lib/ui/workspace_widgets.dart`; category: layout; current note/location header and contextual actions. State props: active selection and action visibility.
- `LumiWorkspace` — Source: `lib/ui/app.dart`; category: layout; responsive application shell around sidebar, main content, and Coach. State props: selected view, selected note, panel visibility, theme.

## Repeated feature components

- `NoteEditor` — Source: `lib/ui/note_editor.dart`; category: basic; note title/body editor with preview and toolbar.
- `SearchResults` — Source: `lib/ui/learning_views.dart`; category: basic; searchable note result list.
- `CanvasView` — Source: `lib/ui/learning_views.dart`; category: basic; learning canvas controls and draggable note cards.
- `KnowledgeGraph` — Source: `lib/ui/learning_views.dart`; category: basic; graph navigation and note nodes.
- `CoachPanel` — Source: `lib/ui/coach_panel.dart`; category: basic; contextual assistant conversation and composer.
- `SettingsPage` — Source: `lib/ui/settings_page.dart`; category: basic; local model and app preferences.
