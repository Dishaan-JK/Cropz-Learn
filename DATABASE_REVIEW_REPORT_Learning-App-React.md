# Database Review Report — Lumi React

**Review date:** 2026-10-20  
**Requested client:** `/run/media/dishaanjk/DevCode/Learning-App-React`  
**Status:** original review; remediation follow-up recorded below. No user workspace data was changed.

## Executive summary

Lumi React is not a database-owning application. It is a TypeScript client that uses the same-origin `/api` contract in `src/lib/lumi-api.ts`. The documented source of truth is the sibling Dart/Genkit service, whose persistence is a set of local JSON files under `LUMI_DATA_DIR` (or `.data` by default), plus image files and Genkit session snapshots.

The design has useful safety controls: loopback binding, typed client calls, bounded request bodies, server-side validation for canvases/learning objects, answer-key redaction, atomic temporary-file replacement for individual stores, and a provider-settings export allowlist. It is suitable for a single-user, local-first prototype once the findings below are resolved.

It is **not safe to describe as protected local storage while arbitrary web origins can call and read the local API**, and its multi-file import/deletion operations are not crash-atomic.

## Scope and method

The requested React repository contains no SQL/NoSQL driver, database schema, or migrations. Its README and backend wiring intentionally preserve the Dart service as the persistence boundary. To review the actual storage model, this report follows that documented boundary into the sibling Lumi service:

```text
React feature components
  -> src/lib/lumi-api.ts
  -> same-origin /api proxy
  -> sibling Dart/Genkit server
  -> JSON files, attachments, and session snapshots under LUMI_DATA_DIR
```

Static code review covered the React request contract, Dart stores/routes, import/export, attachment handling, quiz-answer handling, and related tests. No real user `.data` files, credentials, or live provider calls were read.

## Storage inventory

| Data set | Backing store | Main integrity controls |
|---|---|---|
| Notes | `workspace-notes.json` | Per-store queued writes; temp-file rename; folder existence checked at routes |
| Folders | `workspace-folders.json` | Parent existence and cycle validation; child folders promoted on deletion |
| Canvases / Canvas quizzes | `workspace-canvases.json` | Note-reference, count, title, coordinate, and quiz validation; public quiz DTO removes answers |
| Durable artifacts | `academic-artifacts.json` | Queued writes; structured quiz/flashcard validation; quiz keys omitted from public list |
| User preferences | `user-profile.json` | Explicit preference grammar, length/count limits, credential-word rejection |
| Learning record | `student-learning-record.json` | Event validation, bounded history (2,000), queued writes |
| App settings | `application-settings.json` | Validated patch schema and serialized writes |
| Provider configuration | `provider-settings.json` | API key excluded from public DTO/export; temporary file is chmod 600 on Linux/macOS |
| Images | `attachments/<random-id>.<ext>` | Type sniffing, image geometry, 700 KiB per-upload and 200 MiB total limits |
| Coach sessions | `agent-sessions/` | Session-id validation on deletion; artifact archival is independent of conversation deletion |

## Findings

### DB-01 — High: any website can read and change the loopback workspace

**Evidence:** `bin/server.dart:73-76` binds the service to loopback but sets `corsOrigins` to `['*']`; the Genkit router accepts that list at `bin/server.dart:1023-1033`. The handwritten API separately returns `Access-Control-Allow-Origin: *` for every request carrying an `Origin` header at `bin/server.dart:1053-1061`. There is no request authentication/CSRF check. The API exposes full exports at `bin/server.dart:1099-1135` and permits destructive imports/deletes.

**Impact:** A page opened from an untrusted origin can use the browser to call `http://127.0.0.1:8080`, read notes, artifacts, preferences, learning records, and attachments through the export endpoint, or replace/delete data. Loopback prevents direct remote sockets; it does not prevent cross-origin browser access when CORS explicitly permits it. The threat is local-data exfiltration and destruction, not a claim that the service is Internet-facing.

**Recommendation:** Reject cross-origin requests by default. In development, allow an explicit, exact Vite/Flutter origin allowlist; in production, serve the UI and API from one origin and omit CORS headers. Apply the same policy to the Genkit router. If cross-origin access is a product requirement, use a per-launch, unguessable local bearer token plus strict Origin validation; do not rely on CORS alone for authorization. Add browser-level tests showing a foreign Origin cannot export, import, or call agent routes.

### DB-02 — High: workspace import is not atomic across files or attachments

**Evidence:** The importer validates and stages the payload (`bin/server.dart:1906-1976`), then directly renames each staged JSON file over the live destination, deletes missing live files, recursively deletes the live attachment directory, and finally renames staged attachments (`bin/server.dart:1978-1991`). There is no committed snapshot, rollback path, or recovery marker. The `finally` clause deletes the staging directory (`bin/server.dart:2011-2013`) even after a partial replacement failure.

**Impact:** Disk-full, permission, crash, or rename failure midway through the replacement can leave a mixed-generation workspace or remove the prior attachments. A reload then observes logically inconsistent data, and recovery depends on an external backup.

**Recommendation:** Treat import as a file-set transaction: write and fsync a staging generation, validate it after writing, atomically switch a single current-generation pointer (or rename the complete data directory), retain the previous generation until startup verification succeeds, and provide recovery on the next launch. Test each injected failure point, especially before and after attachment replacement.

### DB-03 — Medium: multi-store mutations can violate referential integrity

**Evidence:** Folder deletion persists the folder collection first and then updates each affected note (`bin/server.dart:1662-1674`). Note deletion persists the note removal first and detaches it from canvases second (`bin/server.dart:1732-1735`). Each JSON collection is written independently; there is no transaction or journal spanning notes, folders, and canvases.

**Impact:** A failed second write can leave notes referencing a missing folder, or canvases referencing a deleted note. The normal happy path is correct, but power loss/I/O failure cannot preserve these cross-file invariants.

**Recommendation:** Route every cross-store mutation through the same generation/journal mechanism as import, validate references before commit, and recover or roll back incomplete transactions at startup. Add failure-injection tests for every step of folder and note deletion.

### DB-04 — Medium: persistence has no versioned schema, migration path, or corruption recovery

**Evidence:** Store loaders directly cast JSON to current model shapes, for example `WorkspaceNote.fromJson` and `WorkspaceNotes.load` at `lib/backend/workspace_notes.dart:31-55`; the service startup loads all stores directly at `bin/server.dart:986-995`. Export/import has a top-level format version fixed at `1` (`bin/server.dart:1906-1910`), but the live store files themselves have no schema version or forward migration registry.

**Impact:** A future field/type change or a partially hand-edited/corrupt local file can prevent startup or silently lose optional data during rewrite. There is no automated way to identify, migrate, quarantine, restore, or report an older on-disk schema.

**Recommendation:** Add a manifest with store versions and a migration ledger. Use immutable, forward-only migrations with a backup/rollback checkpoint; run migrations before loading application state and preserve a readable recovery copy on failure. Add fixtures for every historical version and malformed-file recovery.

### DB-05 — Low: browser-local Coach metadata is not reconciled with server deletion

**Evidence:** Recent Coach session identifiers/titles are stored as arbitrary JSON in `localStorage` at `src/features/coach/CoachPanel.tsx:16-23, 42-49`; deleting a conversation updates only the currently selected session and recent list (`src/features/coach/CoachPanel.tsx:64-71`). Server-side session deletion is validated (`lib/backend/agent_sessions.dart:13-46`), but the client does not reconcile other stale local references.

**Impact:** This is not a server-side data leak by itself. It can leave stale or duplicate recent-session entries after deletion elsewhere, import, or data cleanup, producing confusing restore errors.

**Recommendation:** Validate `agentPath` against the known five paths when reading storage, deduplicate by `(agentPath, sessionId)`, remove all matching recent entries on deletion, and gracefully prune entries after a 404.

## What is working well

- Individual notes, canvases, settings, profiles, learning records, and artifacts use temporary-file replacement. Notes/canvases/profiles/records and artifacts serialize their own queued writes.
- The app binds only to `127.0.0.1`, rather than all interfaces (`bin/server.dart:1006-1021`). This reduces exposure but does not fix DB-01.
- Provider secrets do not appear in the browser-facing provider DTO (`lib/backend/provider_settings.dart:29-35`) and workspace export uses an explicit file allowlist that omits `provider-settings.json` (`bin/server.dart:1099-1115`).
- Quiz answer keys and explanations are stripped from public artifact/canvas list data (`lib/backend/academic_artifacts.dart:34-48` and `lib/backend/workspace_canvases.dart:64-72`), while submission is validated server-side.
- Attachment processing validates declared type against bytes, dimensions, frame count, and storage limits before writing (`bin/server.dart:1178-1219`).
- Request bodies are capped at 1 MiB by default and 300 MiB only for workspace import (`bin/server.dart:1802-1822`, `1136-1142`).
- Existing tests cover basic store round trips, folder-cycle prevention, settings validation/queue recovery, canvas persistence, quiz key redaction, and concurrent artifact collection. They do not cover the findings above.

## Verification performed

| Check | Result |
|---|---|
| `npm run lint` in `Learning-App-React` | Passed |
| `npx tsc --noEmit -p tsconfig.app.json` in `Learning-App-React` | Passed |
| React Vitest suite | Not run: Vite attempted to write `node_modules/.vite-temp` on a read-only mounted target (`EROFS`) |
| React production build | Not run: TypeScript attempted to write `node_modules/.tmp/*.tsbuildinfo` on the read-only target (`EROFS`) |
| Focused Dart persistence tests | Not run: Flutter tried to update its read-only engine cache (`EROFS`) before tests started |

The blocked checks are environment limitations, not test failures. No live backend, local workspace data, authenticated provider, or cross-origin browser proof was exercised in this review.

## Priority remediation plan

1. Fix DB-01 before presenting the local workspace as private: strict Origins and an authenticated local API boundary.
2. Make import a recoverable, generation-level atomic operation (DB-02).
3. Add a shared transaction/journal for cross-file writes and recovery tests (DB-03).
4. Introduce explicit schema versions, migrations, backup, and startup recovery (DB-04).
5. Add the small client reconciliation hardening from DB-05.

## Release assessment

**Do not expose this service to arbitrary browser origins in its current form.** For a strictly single-user local prototype, the core data model and validation are solid, but release readiness requires DB-01 and DB-02 remediation plus failure-injection verification. A future multi-user/networked deployment needs a real authenticated storage service, user/tenant authorization, transactional data store, backups, and audited migrations; it should not extend this filesystem JSON design directly.

## Remediation status — 2026-10-20

The findings above were reviewed against the implementation and remediated in
the sibling Dart service and React client after this report was produced.

| Finding | Remediation | Evidence |
|---|---|---|
| DB-01 | The loopback API now rejects every browser Origin except exact values in `LUMI_ALLOWED_ORIGINS`; it no longer emits wildcard CORS headers. The React full-stack launcher supplies only its selected Vite origin. The same policy runs before Genkit agent routing. | Disposable runtime check: a foreign Origin received `403` for workspace export; configured `http://127.0.0.1:5174` received `200` and an exact allow-origin header. |
| DB-02 | Imports now run through a pre-operation workspace transaction journal with a complete rollback generation, including attachments. A startup recovery step restores the previous generation after an interrupted write. | `WorkspaceTransaction` rollback and startup-recovery tests. |
| DB-03 | Folder deletion and note deletion use the same transaction journal for their related JSON stores, so their reference updates either complete or recover to the pre-operation generation. | Focused transaction rollback coverage plus existing workspace-store regressions. |
| DB-04 | `workspace-schema.json` now records forward-only workspace and per-store versions. Legacy unmanifested data is adopted as v1 without rewriting its payload. Malformed individual stores are quarantined as recoverable `.corrupt-<timestamp>` files instead of preventing startup. | Schema adoption and malformed-store quarantine tests. |
| DB-05 | Coach local metadata is restricted to the five known agent paths, valid session IDs, bounded titles, and deduplicated entries. Deleting a session removes every matching recent entry; a 404 during restore prunes the stale local reference. | React test for malformed/unknown metadata plus existing Coach endpoint tests. |

The JSON store remains deliberately single-user and local-first. A future
networked or multi-user service still needs server-side identity,
authorization, backups, and a transactional datastore.

