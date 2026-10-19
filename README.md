# Lumi Learning App

Lumi is a single Flutter/Dart project containing the learning workspace UI and its local Genkit backend. The Flutter client and HTTP backend share one Dart package, while the backend remains a separate process because the Flutter web app runs in the browser.

## Project structure

- `lib/ui/` contains the Flutter app shell, theme, workspace screens, and widgets.
- `lib/data/` contains the frontend HTTP client and preference helper.
- `lib/backend/` contains local JSON persistence and backend configuration.
- `bin/server.dart` starts the Genkit HTTP service.
- `scripts/` contains isolated Flutter/Dart wrappers and offline regression checks.
- `.data/` stores local workspace data and provider settings on this computer.

The browser communicates with the backend through the existing JSON HTTP API. Provider credentials and workspace data stay on the backend side.

## Requirements

Use the included workspace Flutter SDK wrapper and install package dependencies from the project root:

```sh
./scripts/flutter pub get
```

Install [Ollama](https://ollama.com/), start it, and download the default model:

```sh
ollama serve
ollama pull qwen2.5:3b
```

## Run Lumi

Start the backend from the project root:

```sh
genkit start --non-interactive -- ./scripts/dart run bin/server.dart
```

In another terminal, start the Flutter web app from the same project root:

```sh
./scripts/flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5000
```

Open the URL printed by Flutter. The backend stores workspace notes, canvases, folders, user preferences, and provider settings in `.data/`. Set `LUMI_DATA_DIR` to use another local data directory.

The local backend accepts requests from Flutter's browser development URLs,
including the randomly assigned port used by `flutter run -d chrome`.

The default provider is local Ollama. To change the model, set `LOCAL_MODEL_NAME`; to change its endpoint, set `LOCAL_MODEL_BASE_URL`. The app also supports OpenAI, Anthropic, Gemini, and compatible endpoints through **Settings → AI & models**. Keys entered there are stored by the backend in `.data/provider-settings.json` and are not returned by its settings API.

The Flutter app uses `http://127.0.0.1:8080` as its default backend URL. Override it with `--dart-define=LUMI_SERVICE_URL=http://127.0.0.1:8080` when running Flutter. For an Android emulator, use `http://10.0.2.2:8080`.

If the backend reports that the port is already in use, first check whether a Lumi backend is already running (`ss -ltnp '( sport = :8080 )'`). Do not start a duplicate backend. If another service needs that port, run Lumi on an alternate port and point Flutter to the same port:

In the backend terminal:

```sh
PORT=8081 genkit start --non-interactive -- ./scripts/dart run bin/server.dart
```

In a second terminal:

```sh
./scripts/flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5000 --dart-define=LUMI_SERVICE_URL=http://127.0.0.1:8081
```

## Checks

Run checks from the project root:

```sh
./scripts/flutter analyze --no-pub
./scripts/flutter test --no-pub
./scripts/dart --packages=.dart_tool/package_config.json scripts/lumi_api_regression.dart
./scripts/dart scripts/workspace_regression.dart
./scripts/dart scripts/learning_objects_regression.dart --http
```

## Hugging Face downloads and hardware checks

In **Settings → AI & models → Download from Hugging Face**, enter a public
repository as `owner/model-GGUF`, inspect its files, select a GGUF checkpoint,
choose a context length and execution mode, and press **Check compatibility**.
The backend detects CPU model/threads, available and total RAM, NVIDIA/AMD/Intel
graphics, available GPU telemetry, and readable Ollama storage capacity. Intel
and other integrated graphics share RAM; this memory is counted once. Linux
container memory limits are respected. Hardware probing currently requires a
Linux backend host, and describes that host rather than the browser device.

The check estimates weights, runtime overhead, a conservative KV-cache allowance,
and OS memory headroom. After downloading, exposed attention dimensions can
increase the KV budget before inference starts. It reports likely CPU/GPU load as conditional workload
bands, not promised percentages or tokens per second. Insufficient RAM, known
insufficient disk space, or an invalid required-GPU budget blocks admission.
Unavailable GPU utilisation and protected/unknown storage locations are explicitly
reported; Ollama still enforces disk capacity during the actual pull.
`LUMI_OLLAMA_MODELS_DIR` can point to the daemon's model directory for a readable
pre-download disk check. `LUMI_OLLAMA_URL` defaults to `http://127.0.0.1:11434` and
must point to a loopback Ollama service. Start Ollama separately; Lumi does not
install drivers or reconfigure the daemon.

**Download and use for Lumi** rechecks current resources and repository identity,
streams Ollama download progress, checks the inspected GGUF content hash against
the downloaded layer when Hugging Face supplies a SHA-256, creates a context-bound
Ollama alias, checks advertised chat/tool capabilities, and performs a real tool
call through the same OpenAI-compatible protocol used by Lumi's provider. It
reports the runtime allocation, GPU offload, sampled system CPU/GPU usage, and
system RAM change. Samples include other applications; they are not isolated
model-process RAM or performance benchmarks. **Require GPU acceleration** rejects
CPU fallback; **Auto** reports the actual path. A small smoke test cannot promise
successful completion of every learning task or smooth long-context performance.

Available RAM is checked again at activation, including when the page is reopened.
Only after those checks pass does the page automatically save the local Ollama
connection and reconnect the agent. A newer connection chosen during a download
is preserved. Provider writes are atomic. A cancelled/failed operation leaves the
current agent configuration intact; weights and partial blobs can remain managed
by Ollama. Downloads continue if the page closes; successful pending activation
resumes when AI settings is reopened. Interrupted backend jobs require a fresh
compatibility check. Existing conversations retain their old messages.

This first version supports public, ungated, root-level single-file GGUF text/chat
checkpoints. Private/gated repositories, split shards, projector files, embeddings,
and arbitrary Transformers/Safetensors runtimes are not supported by this flow.
The worker state is `.data/local-model-job.json` (or under `LUMI_DATA_DIR`);
weights remain in Ollama's own storage. Restart Lumi's backend and reload the
client after updating to enable the new routes.

Read-only host/metadata validation:

```sh
./scripts/dart scripts/local_models_smoke.dart
```

An explicit `--download --activate --http` additionally tests a public ~491 MB
checkpoint, saves only disposable provider settings, and verifies a temporary
Lumi backend loads them. It leaves the downloaded Ollama model/alias installed
and unloads the bounded test model afterwards; it preserves the real Lumi data.
Implementation follows the official [Hugging Face/Ollama integration](https://huggingface.co/docs/hub/en/ollama)
and [Ollama hardware support](https://docs.ollama.com/gpu).

## Teaching, assessment, and review agents

Open Lumi Coach and choose **Teach**, **Test**, or **Review**. Teacher lessons
and saved notes can use workspace notes as their source. Tester creates
four-option interactive MCQ quizzes saved directly in Artifacts (or on a new
Canvas when requested), marked mock-test papers, and cumulative revision exams.
Students answer quizzes in Artifacts. Papers can be answered in chat; Tester grades by concepts,
keywords, reasoning, and demonstrated understanding, then records observed
results. Generated assessments are saved to **Artifacts**. Interactive quiz
answer keys remain on the backend until a complete attempt is submitted.
Progress Reviewer reads the same local learning record, summarizes score and
misconception patterns, and can start a due recall review from the Coach panel.

Learning evidence, scores, recurring misconceptions, and review dates are
stored locally in `student-learning-record.json` under `.data/` (or
`LUMI_DATA_DIR`). Review spacing begins at one, three, or seven days based on
the result and can extend after repeated strong performance. The Teacher,
Tester, and Reviewer use this shared record to adapt later work.

## Home navigation

Use **Home** in the sidebar, compact navigation rail, or mobile drawer to return
to the welcome page from any workspace view. Home offers shortcuts to Artifacts,
Canvas, Coach, and note creation. It remains available when notes already exist.
You can also select Home under **Settings → General → Start page**.

## Academic artifacts

**Artifacts** is the default workspace destination. Search every saved material by
its title or full text, filter by type (including quizzes, test papers, and
revision exams), sort, and switch between grid and list
views. Open a saved quiz to choose answers, submit for a score and explanations, and try again. Open a flashcard deck to reveal answers, move between cards, or start over. Interactive objects are labeled in the library. Older text artifacts remain readable and copyable; notes and canvases that still
exist have an **Open in workspace** action.

The backend keeps a separate `.data/academic-artifacts.json` archive (or inside
`LUMI_DATA_DIR`). It indexes existing notes, canvases, learning evidence, and
available completed conversation snapshots on startup. New completed coach
responses are captured by the session store, including lessons, quizzes,
flashcards, test papers, plans, and explanations. Type labels are inferred from
the request; all final text is retained even when its type is uncertain.

Deleting a source note, canvas, conversation, or learning record does **not** erase
its archived material. This is deliberate: the library retains learning history.
Notes and canvases keep their latest saved content, rather than every edit.
Material deleted before this archive existed and absent from saved history cannot
be recovered. Back up the data directory to preserve the archive and attachments.
Ask Coach to “Create an interactive quiz on cells and save it in Artifacts” or
“Create flashcards from this note for later review.” Teacher and Tester use the
`createLearningObject` tool to save validated structured objects. Canvas quiz
creation also archives an interactive copy, which remains available after the
Canvas is deleted. Quizzes support 1–20 four-option questions; decks support
1–100 front/back cards, within the library's content size limit. Existing text
artifacts are not automatically converted into interactive objects.

Practice selections, scores, and card position reset when the reader closes;
the saved questions and cards persist. Library practice does not yet add results
to the shared learning record. Quiz grading uses
`POST /api/artifacts/:id/attempt`; the library GET response omits quiz answer
indices and explanations until submission. Workspace exports include full quiz
marking data for backup.

Restart the backend after updating to load the new tools and grading endpoint.

The sidebar’s **Recently created** section combines the eight newest notes and
canvases, ordered by creation time. **Folders** shows the complete saved learning
workspace: nested folders and their notes, unfiled notes, and canvases with linked
notes. Each item opens directly. This tree represents Lumi data, rather than
host source-code files. The former **All notes** navigation item is removed;
saved notes remain available through the tree, recent items, search, and Artifacts.
Older canvases without a creation timestamp use their existing update timestamp
as a compatible fallback; newly created canvases retain their creation time.


## Settings

The Flutter app includes eight settings pages: General, Appearance, AI & models,
Learning & coach, Workspace & editor, Artifacts & storage, Privacy & data, and
About & diagnostics. Application preferences are validated and saved separately
in `.data/application-settings.json`. The browser caches these preferences for
startup. Use **Save changes** to apply staged edits, or **Discard** to undo them.
Staged application edits survive navigation within the app until saved or discarded. The settings footer shows
**Save changes → Saving… → Saved**. Save is disabled when there are no pending
edits or while a request is running. Failed saves retain edits for retry; edits
made during a request remain pending after that request finishes.
Provider connection changes have their own **Save connection** and **Test connection**
actions. Restart the backend after updating to enable the new settings routes.

Appearance controls apply across the app. Editor, library and startup defaults
apply when opening those views. Learning defaults accompany new coach requests;
a student’s explicit instructions take priority. Disabling remembered preferences
also prevents agent tools from reading or saving the profile. Previous chat turns
may still contain context already sent to the provider.

**Appearance → Canvas** controls the board background. Choose a dot grid (default),
square grid, or plain backdrop. Edit the background and pattern colours using
swatches or a six-digit hex value, with separate palettes for light and dark
mode. The preview reflects staged changes; **Save changes** applies them across
all canvases and persists them locally. **Discard** restores saved values, and
**Reset Canvas appearance** stages the default palette and dot grid. The pattern
moves with the board when you pan or zoom, including beyond its card area.
Restart the backend after updating so it accepts the new Canvas preferences.

**Artifacts & storage → Download workspace export** downloads a JSON data copy,
including notes, folders, complete canvases with assessment marking data, archived
academic artifacts, learning records, explicit preferences, application settings,
and attached images. Provider credentials and conversation session files are
excluded. Exports contain personal academic content; store them privately.
Automatic backups and restoring exports are not implemented in this version.

**Privacy & data** can forget individual or all learning preferences and stage a
reset of application defaults. These actions preserve notes, canvases and the
artifact archive. **About & diagnostics** shows real service/count/storage data
and copies a report containing no credentials or academic content. Service
availability does not prove a successful model response; use **Test connection**.

Settings implementation evidence is in `.project/qa/SETTINGS_IMPLEMENTATION.md`.
