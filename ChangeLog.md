# Change Log

## 2026-10-20

- Reviewed Lumi's persistence and security boundaries across the React client and Dart/Genkit backend. Confirmed the React app uses the backend's local file storage; provider credentials remain backend-owned and quiz answer keys stay out of public artifact responses.
- Routed new Coach turns through `/api/assistant` so the backend delegates requests to the appropriate specialist without a specialist picker in the UI. Preserved streaming and conversation restoration.
- Reworked Canvas into a draggable, pannable study board with note connections and Coach context from linked notes. Added persisted connection validation and corrected drag saves to submit the latest note positions.
- Updated `.gitignore` with targeted exclusions for environment secrets, local workspace data, caches, generated test output, and local design-tool state, while keeping example environment files and design documentation versionable.

### Verification and follow-up

- React typechecking, focused Coach tests, lint, and production build passed during the session.
- Canvas browser interaction and live backend save/readback were not verified because the backend was unavailable during that session.
- The full React test suite still had two unrelated failures involving saved start-page navigation visibility and a Canvas test's expected board.
