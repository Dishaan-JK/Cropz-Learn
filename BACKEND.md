# Backend wiring

The React app is served with a same-origin `/api` contract. During development,
Vite proxies those requests to the existing Lumi Dart/Genkit service at
`http://127.0.0.1:8080` by default.

Run the complete local stack from this project:

```bash
npm run dev:full
```

The launcher first checks whether the backend is already listening, so it does
not start a duplicate process. If needed, it starts the Dart service from the
sibling Lumi project. Override that location with `LUMI_BACKEND_ROOT`, and use
`LUMI_BACKEND_URL` when the backend listens on another local address.
Set `LUMI_FRONTEND_PORT` when an existing development server already uses 5173.
When the launcher starts the backend, it also sets a strict exact
`LUMI_ALLOWED_ORIGINS` list for that Vite port. Do not use a wildcard Origin
allowlist: the local API handles exports, imports, and deletions. If connecting
to a separately started backend, configure its exact UI origin yourself.

The Dart/Genkit service remains the source of truth for provider settings,
agent tools, workspace persistence, and all credentials. React only calls its
public HTTP endpoints through `/api`; no provider keys are exposed to Vite.

## Chrome end-to-end checks

Run `npm run test:e2e:chrome` against a dedicated Chrome session started with
remote debugging enabled, for example:

```bash
google-chrome --user-data-dir=/tmp/lumi-react-e2e-chrome \
  --remote-debugging-port=9223 --no-first-run \
  http://127.0.0.1:5173/
```

Set `LUMI_CHROME_DEBUG_URL` or `LUMI_FRONTEND_URL` when using different local
ports. The suite covers uploads, math rendering, settings, privacy clears,
import/export confirmations, and responsive layouts. Set
`LUMI_E2E_LIVE_COACH=1` to also send one short request through each of the five
Genkit agents; allow extra time when the local model is cold or CPU-bound.
