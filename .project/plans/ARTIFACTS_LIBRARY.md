# Professional academic workspace and artifact library

User request, 19 October 2026: professional UI redesign with an Artifacts page
storing and displaying every academic object created.

This request extends the previous visual-only redesign contract: persistent
artifact storage and an additive GET /api/artifacts endpoint are explicitly in
scope. Preserve the Flutter UI -> repository/API -> independent backend boundary.

Implemented:
- Artifacts as default destination across sidebar, rail, and mobile drawer.
- Professional warm paper/sage library, Lora headings, DM Sans controls,
  consistent button/chip shapes, contextual breadcrumbs, coordinated dark mode.
- Real counts, full-content search, type filters, newest/oldest/title sort,
  grid/list layouts, refresh, empty/offline states, Markdown reader, copy text,
  and source navigation for available notes/canvases.
- Separate atomic JSON archive retaining source-deleted material; existing
  notes/canvases/reviews indexed and available completed chats backfilled.
- Backend session-store capture for final model text; excludes user/system/tool
  messages and tool-call text; deduplicates replayed messages; retains distinct
  regenerated answers. Type classification is heuristic, not semantic certainty.
- Archived attachment references participate in cleanup retention.

Limits:
- Previously deleted and unavailable data cannot be recovered.
- Source notes/canvases retain the latest saved content, not every revision.
- Archive is local to this backend, without cloud sync or cross-device history.
- Final assistant replies are retained as explanations when type is uncertain.
- No new live LLM generation/provider completion is claimed by offline tests.

Design: existing Superdesign project, workspace draft
`e81a43eb-87bf-42cd-91f8-4e1339c7315e`, version 3. User explicitly authorized
sending 13 UI/design context entries after automatic review requested approval.
Implementation follows the generated library; sample design counts are replaced
by actual backend counts. See ../qa/ARTIFACTS_LIBRARY.md for validation.
