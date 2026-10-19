# Workspace sidebar — 19 October 2026

Request interpreted as removal of the **All notes navigation item**, preserving
saved notes. Sidebar/drawer/rail no longer expose that destination.

Implemented:
- Eight recently created notes/canvases in one newest-first list with type icons,
  labels, and direct navigation. Folder selection does not filter this list.
- One scrollable sidebar content region so large trees and recent sections remain
  reachable on smaller screens; settings remain anchored.
- Actual nested folders, their notes, Unfiled notes, and Canvases -> named canvas
  -> linked notes. No fabricated physical filesystem layout or host source files.
- Folder create/rename/delete actions retained. Collapsing hides descendants,
  including nested files; malformed legacy folder structures cannot recurse forever.
- Folder selection picks a note from that folder subtree, rather than leaving an
  unrelated note open. Source note/canvas selection exits search and closes drawers.
- Creation timestamps read by frontend; new canvases persist createdAt independently
  of layout edits and note detachment. Old canvas JSON falls back to updatedAt.

Validation:
- Flutter suite: 39 tests passed, including mixed creation-time ordering, direct
  note/canvas callbacks, nested file rendering, collapse/expand, and persisted
  canvas timestamps across updates/detach/reload.
- Analysis: no issues.
- Workspace regression: 24 assertions passed.
- API regression: 17 assertions passed.
- Release web build: passed using the normal default service URL.

No saved notes, canvases, folders, or archived artifacts were deleted.

Browser review found a pre-existing shell issue: a new Scaffold GlobalKey was
created on every workspace rebuild, resetting sidebar subtree state (including
folder expansion during note saves). The key now belongs to the workspace State;
the file tree also has a stable key within the scrolling sidebar.

Final browser checks passed at 1440×1200 and 390×844 using disposable data:
- All notes navigation absent.
- Recent canvas and note entries open their correct views.
- Collapsing Biology hides Cells and its notes; expanding restores them.
- Selecting a recent canvas on mobile closes the drawer.
- No page errors. Screenshots saved as workspace-sidebar-1440.png and
  workspace-sidebar-390.png; both visually inspected.
- The eight focused sidebar/shell tests pass after the stable state fix.
