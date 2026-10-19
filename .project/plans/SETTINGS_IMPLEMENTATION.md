# Approved settings implementation

Build the eight approved settings sections in Flutter, preserving provider credentials and existing workspace data. Use validated backend persistence for application preferences and retain existing provider connection/test behavior.

Acceptance:
- Responsive category navigation, search, accessible controls, visible save/discard and errors.
- General, Appearance, AI & models, Learning & coach, Workspace & editor, Artifacts & storage, Privacy & data, About & diagnostics.
- Real consumer behavior for appearance, editor, artifact defaults and coach instructions.
- Real diagnostics and credential-free workspace export; explicit confirmation for clearing remembered learning preferences.
- No controls that claim unsupported background scheduling, encryption, synchronization or backup restoration.
- Focused persistence/API/UI tests, existing regression suite, release web build and browser screenshots.

Status: complete. All eight pages implemented and verified. Evidence: `.project/qa/SETTINGS_IMPLEMENTATION.md` and `.project/qa/settings-pages.html`.
