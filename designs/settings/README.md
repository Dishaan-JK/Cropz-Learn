# Lumi settings design images

Design proposal requested on 19 October 2026. These files preserve the original
approved concept. The eight settings sections are now implemented in Flutter;
see `../../.project/qa/SETTINGS_IMPLEMENTATION.md` for actual behavior and evidence.
The images below remain concept images, rather than screenshots of the running app.

The suite covers General, Appearance, AI & models, Learning & coach,
Workspace & editor, Artifacts & storage, Privacy & data, and About & diagnostics.
The pack contains 21 PNG page images: 16 standard desktop views, 2 cloud-provider
examples, and 3 mobile previews. Light and dark desktop images are exported
from one consistent interactive design prototype.

Open `index.html` for the image gallery or `prototype.html` for the interactive
concept. Buttons in the prototype do not save settings, call providers, export
user data, or erase anything. Provider connection and service states are neutral.

The archive and folder structure reflect the current local-first Lumi app.
Future implementation should preserve existing notes, canvases, conversations,
artifacts, explicit preferences, and backend-owned provider credentials.

Two overview PNGs summarize all eight sections. The prototype includes its fonts,
icons, and compiled styles for offline review; applicable licenses are included.

Validation: all eight category buttons and the mobile picker were exercised in
headless Chrome; all 19 standard exports rendered without page errors or horizontal
overflow. The cloud key field is empty and appears only for cloud providers. No
provider requests, data exports, deletion, or app-settings changes were performed.
