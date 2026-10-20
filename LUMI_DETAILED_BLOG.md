# Lumi: a learning workspace that stays yours

> **A detailed product blog and technical explainer**  
> Updated for the current local-first Lumi build — 20 October 2026

Learning apps are often good at one moment: answer a question, summarize a PDF, or generate a quiz. The harder problem is helping a learner build a body of work over time—notes, visual thinking, practice, feedback, misconceptions, revision plans, and the evidence needed to improve. Lumi is designed for that longer journey.

Lumi is a local-first learning workspace built with Flutter and Dart. It brings notes, canvases, saved academic materials, interactive practice, and specialist learning agents into one workspace that the learner controls. Its central idea is simple: AI should work *with* a learner's materials and progress, without forcing the learner to surrender their whole workspace to one hosted product or one model vendor.

This article explains what Lumi is, how it differs from source-grounded notebook assistants such as Google NotebookLM, what Lumi currently does, where its data is stored, and what “model independence” means in practice.

## What is Lumi?

Lumi is an academic workspace with an AI learning coach at its centre. A student can write and organise notes, build a visual Canvas, ask for an explanation, create a quiz or flashcards, complete practice, and return later to a library of the materials they created.

Rather than treating an answer as disposable chat output, Lumi turns useful work into durable learning objects. A revision plan, a set of flashcards, an interactive multiple-choice quiz, a test paper, an explanation, or a review can be kept in **Artifacts**, a searchable library designed for later study.

Lumi's coaching system has distinct responsibilities:

| Agent | Purpose | What it can use or create |
| --- | --- | --- |
| **Coach** | Routes a learning request and helps with general revision. | Notes, Canvas work, learning context, and specialist hand-offs. |
| **Teacher** | Explains topics and builds learning material. | Local workspace notes, lessons, flashcards, quizzes, and saved learning objects. |
| **Tester** | Creates and marks practice. | Interactive four-option quizzes, mock tests, revision exams, and marking feedback based on concepts, keywords, reasoning, and demonstrated understanding. |
| **Progress Reviewer** | Helps make progress visible. | A shared local learning record: score trends, misconceptions, due reviews, and observed evidence. |

The division is deliberate. A review should not pretend to know a learner's weaknesses without evidence; a test should not be just another generic chat reply; and a useful lesson should be able to become a resource the learner can revisit.

## Lumi is more than an AI chat window

The workflow is designed around learning continuity:

1. **Capture and organise.** Create notes, folders, attachments, and visual Canvases in the workspace.
2. **Learn with context.** Ask the Coach or Teacher to explain, connect, or transform selected material.
3. **Practise actively.** Generate interactive quizzes, flashcards, mock tests, and revision exams instead of stopping at a summary.
4. **Keep the output.** Saved material appears in Artifacts, not only in a chat scrollback.
5. **Review evidence.** The Reviewer uses recorded results and recurring misconceptions to recommend a concrete next step and spaced recall review.

The current learning record stores dated evidence, scores, misconception patterns, and review dates locally. Initial review intervals are one, three, or seven days according to the observed result and can grow after repeated strong performance. The reviewer is instructed to distinguish repeated evidence from a one-off result and to say when there is not enough information.

## How Lumi differs from NotebookLM and similar apps

NotebookLM is an excellent example of a *source-grounded notebook assistant*: you add sources, then ask questions against them. Google describes its notebook chat as using selected sources and conversation context to produce answers, often with citations. That makes it especially valuable when the main task is to interrogate a supplied collection of documents.

Lumi overlaps with that use case—Lumi can search and read workspace notes—but it has a different centre of gravity. It is a learner-owned workspace and practice loop, rather than a hosted source notebook tied to one AI product.

| Question | Lumi | NotebookLM and similar hosted notebook tools |
| --- | --- | --- |
| **What is the primary unit of work?** | A continuing learning workspace: notes, Canvas, Artifacts, practice, and evidence. | Usually a notebook built around uploaded or connected sources. |
| **Where is the working data kept?** | By default, in a local Lumi data directory on the computer running the backend. | In the provider's hosted service and account environment. |
| **Can I choose the AI provider?** | Yes. Local Ollama is the default; OpenAI, Anthropic, Google Gemini, and OpenAI-compatible endpoints can be selected. | The model and service are selected by the hosted product. |
| **Can I work fully locally?** | Yes, when using a loopback-only Ollama endpoint and local workspace data. | Not as a normal hosted-service workflow. |
| **What happens after content is generated?** | It can be saved as a durable Artifact, quiz, flashcard deck, Canvas item, or learning evidence. | Output normally lives in the hosted notebook experience. |
| **Does it track learning progress?** | Yes. Lumi has a shared local evidence record for teaching, testing, and review. | Source-grounded notebook tools focus primarily on source interaction; feature sets vary by provider and plan. |
| **Can it create active practice?** | Yes: interactive quizzes, flashcards, tests, revision exams, and review prompts. | Many notebook tools can generate study aids, but their storage, scoring, and follow-up workflow are product-specific. |

This is not a claim that one category is universally better. NotebookLM can be a very good choice when a learner wants a polished cloud notebook for a set of sources and citations. Lumi is for learners who also want a local workspace, durable academic objects, evidence-led review, and the freedom to select how AI is provided.

For a current description of NotebookLM/Gemini Notebook capabilities and data terms, consult Google's own help and privacy pages rather than relying on a feature comparison that may age quickly:

- [Gemini Notebook frequently asked questions](https://support.google.com/gemininotebook/answer/16269187?hl=en)
- [Gemini Notebook privacy information](https://support.google.com/notebooklm/answer/16164461?co=GENIE.Platform%3DDesktop&hl=en)

## The features that make Lumi a learning system

### A calm, structured workspace

Lumi includes folders, notes, a workspace tree, recent work, attachments, and a visual Canvas. The Canvas is not a decorative whiteboard: it can hold connected notes and interactive quiz cards. Learners can choose a dot grid, square grid, or plain background and adjust separate light and dark pattern colours.

### Artifacts: a lasting academic library

Artifacts is a searchable library for every academic object Lumi creates or captures: notes, lessons, explanations, quizzes, flashcard decks, test papers, revision exams, and reviews. It can be filtered by type, sorted, and displayed as a grid or list.

This matters because a generated quiz should still be useful next week. An Artifact remains available even if the source Canvas, note, or conversation is later removed. That retention is intentional, so learners should use the workspace export and deletion controls with care.

Interactive objects have real behaviour:

- Quizzes support one to twenty four-option questions.
- Flashcard decks support one to one hundred front/back cards.
- Quiz answers and explanations are held on the backend until the learner submits a completed attempt.
- A learner can see a score, explanations, and retry the activity.
- A Canvas quiz can also create an interactive Artifacts copy for later use.

### Assessment that values understanding, not a phrase match

The Tester is intended to assess concepts, keywords, reasoning, and demonstrated understanding rather than require one exact wording. It can create low-stakes practice, mock tests, and revision exams, then record observed results in the shared learning record. This creates a basis for a later review rather than asking the learner to trust a generic “you are doing well” response.

### Evidence-led review and spaced recall

The Progress Reviewer reads the same local record used by Teacher and Tester. It can identify topic patterns, recurring misconceptions, and due reviews, then invite a learner to answer a short recall question. It does not have permission to invent progress: a review outcome is recorded only after an observed answer or result.

### Settings built for control

Lumi has separate settings for appearance, learning and coach behaviour, workspace/editor defaults, Artifacts/storage, privacy/data, and AI/models. Remembered preferences are opt-in: Lumi only stores an explicit preference when the learner asks it to remember it, and the setting can disable agents from reading or saving those preferences.

## Model independence: choose how Lumi thinks

One of Lumi's defining principles is that its workspace should not be locked to a single model company. The **AI & models** settings support:

- **Local Ollama** — the default, with a loopback endpoint such as `http://127.0.0.1:11434/v1`.
- **Google Gemini** — via the official Gemini API.
- **OpenAI** and **Anthropic** APIs.
- **Other OpenAI-compatible APIs** — useful for compatible self-hosted or third-party model servers.
- **Local model downloads through Ollama** — Lumi can inspect public GGUF model files, estimate hardware compatibility, download through Ollama, test tool calling, and activate a successful model.

This choice lets a learner make a sensible trade-off for each installation:

| If the priority is… | A suitable Lumi setup is… |
| --- | --- |
| Maximum local control | Local Ollama on the same computer, bound to loopback. |
| A no-cost cloud starting point | Google Gemini's available API free tier, within Google's current limits and terms. |
| A preferred commercial model | Connect the provider's own API and choose an available model. |
| A specialised or self-hosted compatible model | Connect an OpenAI-compatible endpoint that the learner operates or trusts. |

### A precise note about “a model for every agent”

Lumi already gives the learner independence to choose the **active model connection** used by Lumi's agents. That choice can be changed without moving notes, Artifacts, or learning history to another application.

The current implementation uses **one active provider/model configuration shared by Coach, Teacher, Tester, and Reviewer**. It does **not** yet expose a UI for assigning a different model to each specialist agent. This is an important distinction: per-agent model routing is a strong future direction—for example, a local model for private note work and a larger cloud model for a complex explanation—but it is not something this version should claim to ship already.

The architecture makes that future meaningful: agent roles, tools, records, and outputs are separated. When per-agent routing is introduced, it should remain explicit, inspectable, and reversible, with a clear disclosure of which provider receives each request.

## Google Gemini free-tier option

For a learner who wants to try capable cloud AI without immediately enabling billing, Lumi includes a guided Google AI Studio setup in **Settings → AI & models**:

1. Create a Google AI Studio API key.
2. Select **Google Gemini** in Lumi.
3. Paste the key, choose a model, test the connection, and save it.
4. Do not enable billing if free-tier-only use is the goal.

Free access is governed by Google, not Lumi. Limits are model-specific, can change, and requests can pause when a limit is reached. The learner should check the current billing, rate-limit, and data terms in Google AI Studio before using the option for sensitive material.

Lumi stores a configured API key on its local backend and never returns that key to the browser through its settings API. On Linux and macOS, the provider settings file is written with owner-only `600` permissions. This protects the browser boundary; it is not a replacement for device security, full-disk encryption, or good operating-system account hygiene.

## Privacy and security: where Lumi data stays

The most useful privacy promise is a precise one, not a vague one.

### The local-first default

By default, Lumi stores workspace data on the computer running its backend, in the project's `.data/` directory. An installation can set `LUMI_DATA_DIR` to place that local data elsewhere. The local backend normally listens at `127.0.0.1:8080`, while the default Ollama endpoint is also loopback-only.

The locally persisted data includes:

| Local file or directory | What it contains |
| --- | --- |
| `workspace-notes.json` | Notes and their workspace metadata. |
| `workspace-folders.json` | Folder organisation. |
| `workspace-canvases.json` | Canvases, layout, and Canvas quiz data. |
| `academic-artifacts.json` | The durable Artifacts library. |
| `student-learning-record.json` | Learning evidence, scores, misconceptions, and due reviews. |
| `user-profile.json` | Explicitly remembered preferences. |
| `application-settings.json` | Lumi application preferences. |
| `attachments/` | Locally stored attached images. |
| `agent-sessions/` | Persisted conversation/session snapshots. |
| `provider-settings.json` | Selected provider/model and, for a cloud provider, its API key. |

With local Ollama, a loopback-only configuration, and no action that fetches a model, the learning workspace and AI request path remain on the local machine. That is the strongest “data does not leave” mode Lumi offers.

### The cloud-provider boundary

Selecting Gemini, OpenAI, Anthropic, or another remote compatible endpoint changes that boundary. Lumi's local backend sends the model request—and the prompt, conversation context, and any workspace content deliberately included by the request or the agent's tools—to the chosen provider so it can generate a response. That material leaves the device for that request and is then governed by the provider's terms, retention, and data controls.

So the accurate promise is:

> **Lumi does not run its own hosted data cloud or silently upload a learner's workspace. Local Ollama keeps model work local. If a learner explicitly connects a cloud AI provider, only the context needed for that provider request can leave Lumi's local backend.**

That boundary should be visible to the learner, especially when using a free cloud tier. Local-first storage does not erase a cloud provider's own policy once a learner asks that provider to process content.

### Practical safeguards already in Lumi

- **Backend-owned credentials:** the API key is not serialized back to the browser; the public settings response reports only whether a key is configured.
- **Restricted local service:** the default application service uses a loopback address rather than intentionally exposing the workspace to a network.
- **Sensitive preference protection:** a user-profile validator rejects obvious credentials such as passwords, API keys, access tokens, and secrets from remembered-preference storage.
- **Answer-key separation:** Artifacts list/read responses omit quiz answer indices and explanations until an attempt is submitted to the local backend.
- **Controlled exports:** workspace exports include academic content and attachments, but intentionally exclude provider credentials and conversation session files.
- **Export/import validation:** imports accept a limited Lumi workspace format and validate its files and attachments before replacing export-managed data.
- **Local deletion controls:** the learner can forget individual preferences, clear all remembered preferences, clear learning evidence, delete notes and sessions, and manage the local data directory.

### What users should do to keep Lumi private

1. Prefer **Local Ollama** for material that must never be sent to a remote AI provider.
2. Keep Lumi and Ollama bound to loopback unless there is a deliberately secured networking design.
3. Protect the computer account and use disk encryption where appropriate; local files are only as safe as the device that stores them.
4. Treat workspace exports as sensitive academic data and store them privately.
5. Review the provider's current data terms before connecting any cloud endpoint, especially a free tier.
6. Remove a provider connection or rotate its key if a credential may have been exposed.

## Ownership, portability, and honest limitations

Lumi offers a JSON workspace export containing notes, folders, full Canvas data, assessment data, Artifacts, learning records, explicit preferences, application settings, and attached images. Provider credentials and conversation session files are excluded from the export. Importing an export requires confirmation because it replaces the export-managed workspace data.

This means Lumi supports portability, but it does not yet mean that every form of data is automatically backed up or deleted by one master switch. In particular:

- Automatic scheduled backups are not implemented in the current version.
- Artifacts deliberately survive deletion of their source note, Canvas, or conversation; delete the Artifact or its underlying local data when that retention is not wanted.
- Existing provider connection settings and conversation sessions are outside the workspace export/import bundle.
- A cloud provider may retain or process data according to its own terms after a request reaches that provider.

Being clear about these limitations is part of respecting learner ownership.

## Why this approach matters

Lumi is built on the belief that educational AI should strengthen a learner's agency. The learner should be able to:

- keep a body of study work rather than lose it in chat history;
- see why a review recommendation was made;
- choose a private local model or an external provider according to need;
- move their workspace as a file they can keep;
- decide what Lumi remembers; and
- use generated material again as practice, not merely read it once.

The goal is not to make AI invisible. It is to make the boundaries legible: what is saved, what is shared, which model is active, what an agent is allowed to do, and how the learner can take their work with them.

## Feedback, reviews, and recommended fixes are welcome

This blog is a living product document. Reviews are welcome—especially reports that make Lumi safer, more accurate, more accessible, or more useful for real learners.

Please include the following in a review or recommended fix:

- the section or claim being reviewed;
- the observed behaviour and steps to reproduce it, where applicable;
- the expected behaviour or a specific wording correction;
- privacy, security, accessibility, learning-design, or technical impact; and
- a proposed fix, trade-off, or source when one is available.

Particularly valuable feedback includes corrections to data-flow claims, provider-boundary wording, export/deletion behaviour, assessment fairness, accessibility, and the future design of per-agent model selection. Lumi should earn trust by being specific, correcting mistakes openly, and making user control more real with every iteration.

