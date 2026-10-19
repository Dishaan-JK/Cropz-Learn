# Lumi Web UI Redesign Handoff

**Status:** Approved; implementation is in progress. See [WEB_UI_REDESIGN_PROGRESS.md](WEB_UI_REDESIGN_PROGRESS.md) for shipped slices and verification limits.  
**Audience:** A future Codex session or engineer implementing the web UI refresh.  
**Product:** Consolidated Lumi Flutter web app in this repository.

## Goal

Give Lumi a distinctive, calm study atmosphere that makes opening the workspace feel like settling in to read and learn. The interface should feel warm, clear, and focused across the complete app, while retaining all existing user workflows and backend behavior.

The approved direction is **warm paper and sage**: soft paper backgrounds, warm white content surfaces, muted sage as the main action color, deep ink for text, and restrained terracotta for occasional emphasis. Use typography and spacing to make the app comfortable for longer study sessions. The goal is to support focus through the visual environment; do not make claims that the UI will cause a particular mood or outcome.

## Decisions to Preserve

- Redesign all existing screens: workspace navigation, folders, note editor, search, canvas, knowledge graph, Lumi Coach, and settings.
- Preserve existing interactions, routes/views, API and repository contracts, data behavior, and backend ownership. This is a UI refresh, not a feature redesign.
- Retain both light and dark themes. The light theme is the primary approved art direction; make the dark theme a coordinated warm, low-glare variant with sage accents.
- External Flutter UI dependencies are allowed. Add only the selected font and icon dependencies unless implementation discovers a concrete requirement that cannot be met by them.
- Bundle font files locally; do not depend on a runtime font download for initial or offline rendering.
- Keep UI implementation inside `lib/ui/`; do not move backend or data responsibilities into widgets.
- Use the project’s existing Flutter SDK constraint (`>=3.4.0 <4.0.0`) when resolving dependencies. Pin or constrain dependency versions so the app remains buildable with the project’s supported Dart range.

## Current Project Map

- `lib/ui/app.dart` composes the workspace, holds view/selection presentation state, and currently selects layout using width checks around 760 and 1180 pixels.
- `lib/ui/lumi_theme.dart` defines the shared light/dark themes and `LumiTokens` extension.
- `lib/ui/workspace_widgets.dart` contains the sidebar, navigation rows, note tiles, and workspace top bar.
- `lib/ui/note_editor.dart` contains note editing, toolbar actions, save feedback, and Markdown preview.
- `lib/ui/learning_views.dart` contains search results, welcome state, canvas, and knowledge graph.
- `lib/ui/coach_panel.dart` contains the coach conversation panel and dialogs.
- `lib/ui/settings_page.dart` contains settings sections.
- `lib/data/workspace_repository.dart` and `lib/data/lumi_api.dart` own workspace API coordination and HTTP behavior; preserve this boundary.
- Existing automated tests cover API, preferences, and workspace stores. There are no UI widget tests listed in `test/` today.

Before implementation, inspect these files and current `pubspec.yaml`/lock state again. Do not assume the handoff’s paths or dependency versions have stayed unchanged if the repository has moved on.

## Visual System

### Palette and surfaces

Create named theme tokens rather than scattering literal colors through widgets. Use this palette as the starting point, adjusting values as needed to pass contrast checks:

| Role | Starting direction |
|---|---|
| App canvas | Warm paper, approximately `#F4F1E8` |
| Main content surface | Warm white, approximately `#FFFCF5` |
| Primary text | Deep ink, approximately `#292D28` |
| Secondary text | Muted olive-gray with sufficient contrast |
| Primary action/selection | Muted sage, approximately `#71836A` |
| Small emphasis | Restrained terracotta, approximately `#B8795E` |
| Borders | Soft warm gray, not pure black or high-contrast outlines |

These are starting values, not a reason to sacrifice accessibility. Maintain WCAG AA contrast for text and controls, especially muted text and selected navigation. Keep most surfaces quiet; reserve accent colors for actions, current selection, and important state. Avoid gradients, saturated color blocks, heavy drop shadows, and full-page textures.

Use a very subtle paper or botanical detail only in the welcome/empty treatment, if it remains unobtrusive and renders cheaply. Do not put a texture behind note text, graph labels, or chat messages.

### Typography and icons

- Use **DM Sans** for interface text and **Lora** sparingly for editorial headings and reading-oriented accents.
- Bundle only the required font weights as local assets; include the applicable font license files and make the fonts available to Flutter’s font loader/package configuration.
- Use `google_fonts` as the Flutter font integration, configured to use bundled assets and with runtime fetching disabled. Since the repository supports Dart 3.4, select a compatible release rather than blindly taking a newer release that raises its minimum SDK. The `6.3.0` line is a candidate with a compatible SDK floor; verify the resolver and API before implementation: [google_fonts versions](https://pub.dev/packages/google_fonts/versions).
- Replace the current mixed Material icon styling with a consistent Lucide outline set using `lucide_icons_flutter`; preserve familiar meanings and tooltips. Its `3.1.x` line supports the project’s Dart SDK constraint and Flutter web: [lucide_icons_flutter versions](https://pub.dev/packages/lucide_icons_flutter/versions).
- Keep icons paired with accessible labels where meaning is not obvious. Do not use icons as the only way to identify destructive actions.

### Shape, spacing, and motion

- Use a consistent spacing scale based on 4 or 8 pixel increments; make major regions more open than dense settings controls.
- Standardize corner radii: modest rounding for fields and controls, slightly larger rounding for cards/panels. Avoid making every control pill-shaped.
- Prefer fine borders and small, soft elevation differences to establish hierarchy.
- Use brief, subtle transitions for navigation/panel appearance (roughly 150–220 ms). Avoid continuous motion, parallax, bouncing, and attention-grabbing animations. Respect the platform’s reduced-motion setting.

## Responsive Workspace Layout

Use `LayoutBuilder` or a shared breakpoint helper so the shell and its children agree on available width. Breakpoints refer to logical pixels.

### Wide: 1280 px and above

- Show a full workspace sidebar around 250–270 px wide, the main view, and an optional coach panel around 330–360 px wide.
- Keep the reading/editor column around 760–840 px maximum for comfortable line length; center it within remaining space when there is room.
- The sidebar groups New note and search first, workspace destinations next, then scrollable folder and recent-note areas, with Settings and the local-workspace label at the bottom.
- When Coach is open, shrink the main region gracefully; do not obscure editor actions.

### Medium: 768–1279 px

- Keep a compact navigation rail around 68–76 px wide.
- Open folders/recent notes in a dismissible side panel or drawer from the rail. The panel must expose all existing folder, create, rename, delete, and note-selection actions.
- Present Coach as a temporary side drawer or overlay. Close it predictably with an explicit control and Escape/back behavior where applicable.
- Avoid clipping top-bar actions; move low-frequency actions into an overflow menu if necessary while preserving access.

### Narrow: below 768 px

- Use a compact top bar and a navigation drawer for destinations, folder tree, recent notes, search, and create-note action.
- Keep the editor full width with responsive horizontal padding and a usable toolbar that can wrap or scroll without hiding controls.
- Present Coach in a full-height dialog/sheet appropriate to the browser viewport, with a clearly visible close action and composer anchored above the keyboard/viewport edge.
- Preserve Canvas and Graph pan/zoom/drag access with touch and pointer input; controls must not occupy so much space that the content becomes unusable.

Do not add a second permanent bottom navigation that duplicates every workspace destination. Keep the hierarchy compact and consistent with the existing workspace model.

## Screen-by-Screen Direction

### Workspace shell and navigation

- Give the workspace a warm background with clearly separated, quiet navigation and content surfaces.
- Refine the brand header and navigation hierarchy. Use concise section labels and consistent icon alignment, selected state, hover state, keyboard focus, and tooltips.
- Make folder hierarchy scannable and scroll independently from recent notes. Preserve nested folders and all context-menu actions.
- Make New note visually prominent but calm. Make search easy to find on all breakpoints.
- Use a top bar with current location/title, save status, and contextual actions. Provide clear responsive handling for Search, New note, Delete, Settings, and Coach.

### Note editor and Markdown preview

- Establish a reading-first content column with generous line spacing, clear title/body distinction, and predictable toolbar placement.
- Make edit/preview states, formatting actions, image insertion, note links, and slash menu visually consistent with the new palette.
- Show save state as a small but legible status: saving, saved, or failed/retry. Never communicate success only through a transient color.
- Preserve autosave, draft recovery, image upload, folder move, and Markdown capabilities.
- Keep line length and controls comfortable on narrow screens; do not create horizontal page overflow.

### Search and empty/error states

- Give search results clear title, preview, and selection feedback; distinguish no matches from an empty workspace.
- Make recovery from backend-unavailable state visible and actionable while retaining the current retry behavior.
- Use a welcoming but quiet study-oriented empty state with one clear next step. Avoid motivational copy that feels pushy or implies productivity tracking.

### Canvas and knowledge graph

- Apply shared card, label, and control styles without disrupting their existing interactive surface.
- Keep canvas pan, zoom, reset, drag, note selection, and connection affordances visible and discoverable.
- Keep graph nodes, backlinks, arrows, and link-editing controls distinguishable in both themes. Ensure edge and node contrast remains adequate.
- Ensure floating controls do not cover cards or consume the full viewport at tablet/mobile sizes.

### Lumi Coach

- Style the panel as a quiet reading/conversation surface with clear assistant/user message distinction, generous message spacing, and an anchored composer.
- Keep route/specialist context and existing conversation controls discoverable. Preserve conversation restore and “Start a new conversation” confirmation behavior.
- Make the panel layout work as a desktop side panel, medium overlay, and narrow full-height view.

### Settings and dialogs

- Use consistent section headings, cards, labels, form fields, and feedback states.
- Preserve current settings actions and light/dark toggle.
- Standardize dialogs, confirmation hierarchy, cancellation, focus order, and keyboard dismissal where safe. Destructive actions need explicit labels and a clear cancel path.

## Suggested Implementation Slices

Complete, review, and verify each slice before starting the next. The approved workflow from the user is to have an ECC UI reviewer inspect the running app in Chrome and an architecture reviewer check code quality/structure after each feature slice.

1. **Theme foundation:** Add compatible font/icon dependencies, bundle fonts and licenses, introduce tokens and common theme styles, and check both themes before broad widget changes.
2. **Responsive shell:** Implement breakpoints, sidebar/rail/drawer, top bar, notes/folders panel, and Coach presentation modes. Verify existing navigation callbacks still behave the same.
3. **Workspace content:** Refresh editor, Markdown preview, search, note/folder rows, welcome/empty/error/save states.
4. **Learning views:** Refresh Canvas and Graph visual controls, cards, nodes, edges, and responsive behavior without changing their operations.
5. **Coach and settings:** Refresh chat, composer, settings sections, and shared dialogs/menus. Preserve session and settings behavior.
6. **Polish and acceptance:** Fix review findings, confirm keyboard/focus/contrast and responsive overflow, then update project documentation with actual verification evidence.

Use the existing ECC agents/review skills where available; do not claim a Chrome check if the latest build cannot be loaded. Report any environment limitation and distinguish a screenshot of an older tab from a fresh run of the implemented revision.

## Testing and Acceptance Criteria

### Automated checks

- Run `./scripts/flutter analyze --no-pub`.
- Add focused Flutter widget tests under `test/` for shell rendering at wide, medium, and narrow constraints; drawer/rail/sidebar navigation; Coach open/close mode; editor/save-state rendering; and representative empty/error states.
- Verify representative controls have semantic labels and keyboard focus can reach navigation, search, editor tools, Coach controls, and dialogs.
- Run relevant existing tests with `./scripts/flutter test --no-pub` and preserve API/workspace regressions.
- Run `./scripts/flutter build web --no-pub` after the final UI changes.

### Chrome review

- Inspect a fresh app build at 1440×1000, 1024×768, and 390×844 (or the closest available viewport sizes).
- Check both light and dark themes at desktop and narrow sizes.
- Verify no clipped labels, hidden actions, unwanted horizontal page scroll, modal overflow, or unreadable contrast.
- Review Notes/editor, Search, folder tree, Canvas, Graph, Coach, and Settings.
- Exercise navigation and view switching. For any save/edit check, use a disposable/demo note or create and clean up a test note; do not alter a user’s existing note as test data.
- Capture screenshots or concise evidence for each viewport and record any UI agent findings and fixes.

### Completion criteria

- All current user workflows remain present and functional; there are no backend/API changes.
- The visual system is consistent across all listed screens and both themes.
- Desktop, medium, and narrow layouts work without clipped controls or unintentional overflow.
- Automated checks and production web build pass.
- ECC architecture and Chrome UI reviews are completed for each slice, and their findings are resolved or explicitly documented.
- `.project/qa/QA-1.md` or a linked UI-specific QA note records actual results and outstanding limits; do not mark untested features as verified.

## Explicit Non-Goals

- No changes to Genkit, providers, HTTP endpoints, workspace persistence, note schemas, or repository contracts.
- No new study/productivity features, progress tracking, timers, gamification, or forced motivational messaging.
- No large decorative imagery, loud gradients, constant animation, or runtime font download requirement.
- No removal or simplification of folder, editor, canvas, graph, Coach, or settings capabilities.
