# Lumi React

Lumi React is the browser client migration for the Lumi learning workspace. It
uses React, TypeScript, Vite, TanStack Query, and Lucide icons while preserving
the existing Dart/Genkit service as the backend boundary.

## Current slice

The initial React implementation provides a responsive warm-paper/sage workspace
shell. It loads notes and folders from Lumi, handles loading and backend errors,
creates and edits notes through the existing API, and includes a compact
command-style note search dialog. It also exposes the approved compact Coach
rail and a persistent Artifacts library with local search, kind filters, and
detail views. Saved flashcards can be reviewed in-place and saved quizzes are
scored through Lumi's existing backend endpoint. Canvas, graph, settings, and
live Coach chat are deliberately left for later migration slices.

## Run locally

Start the existing Lumi Dart/Genkit backend first, then run:

```bash
npm install
npm run dev
```

To launch the React app from this project with its local Lumi backend, use:

```bash
npm run dev:full
```

See [BACKEND.md](BACKEND.md) for the same-origin proxy and backend-root setup.

The client calls `http://127.0.0.1:8080` by default. To use a different local
backend, provide a Vite environment variable:

```bash
VITE_LUMI_SERVICE_URL=http://127.0.0.1:8081 npm run dev
```

Provider credentials stay on the backend. They must never be added to Vite
environment variables exposed to the browser.

## Checks

```bash
npm run lint
npx vitest run
npm run build
npm run test:e2e:chrome
```

## Single executable (Linux x86_64)

With the sibling `Learning-App` Dart backend checkout and Rust installed, run:

```bash
npm run bundle:single
```

This builds `release/lumi-linux-x64`, a single Linux executable containing the
production web UI and compiled Lumi backend. It starts the app on a loopback
port and opens the default browser. Workspace data stays in
`$XDG_DATA_HOME/lumi` (or `~/.local/share/lumi`); set `LUMI_DATA_DIR` to choose
another location. Provider credentials remain in that local data directory.
The executable can run without Node, Dart, or the source checkouts installed.
Build it separately on each target OS and CPU architecture; this script emits
Linux x86_64 only.

## Design reference

The approved concept is the [Lumi React Workspace canvas](https://superdesign.dev/teams/a4c9d57a-42d9-4578-8e2e-a8209329992f/projects/f6b6afec-4846-449e-b392-21418bc6047b).
Its generated HTML is a visual reference only; this project deliberately uses
local source, package dependencies, and no runtime CDN assets.
