# Interactive learning objects

Implemented 2026-10-19.

## Behavior

- Teacher and Tester have a `createLearningObject` Genkit tool with validated structured quiz questions or flashcard fronts/backs.
- Coach delegates flashcards to Teacher and quizzes to Tester. Agent instructions require structured object creation and confirmed saves.
- New quizzes default to Artifacts; explicitly requested Canvas quizzes preserve the existing Canvas workflow and archive an independently reusable interactive copy.
- Objects persist in academic-artifacts.json. Existing library type filters, title/content/source search, sorting, and list/grid layouts organize them for later review.
- Artifacts opens quizzes with selectable options, complete-attempt submission, server scores, explanations, and retry. Flashcards offer answer reveal/hide, previous/next navigation, and restart.
- Library GET responses omit quiz marking keys and explanations; POST /api/artifacts/:id/attempt returns feedback after validating every submitted answer.
- Older Markdown artifacts retain their reader. No automatic conversion of historical text is attempted.
- Practice selections, results, and card position are session state. They reset when the reader closes; these attempts are not added to the shared learning record.

## Verification

- `./scripts/dart --suppress-analytics analyze`: no issues.
- `./scripts/flutter test --no-pub`: 62 tests passed.
- `./scripts/dart scripts/learning_objects_regression.dart --http`: 13 checks passed, exercising actual Genkit tool callbacks, disk reload, the existing Canvas creation tool, library HTTP loading, encoded artifact IDs, grading feedback, and rejection of incomplete attempts. Uses disposable storage and shuts down its temporary backend.
- `./scripts/dart --packages=.dart_tool/package_config.json scripts/lumi_api_regression.dart`: 17 assertions passed.
- `./scripts/dart scripts/workspace_regression.dart`: 24 assertions passed.
- `./scripts/flutter build web --release --no-pub`: passed; build/web generated. Build reports a Cupertino font reference warning.
- Review widget tests cover 390px and 1180px widths in light/dark themes, reveal/navigation/reset, quiz submission failures and retry, and reopening from the actual Artifacts page.

Flutter tests and HTTP verification required execution with local socket access because the sandbox blocks loopback server binding. No user workspace data or provider settings were modified by the smoke checks.

## Evidence limits

The actual tool callbacks and HTTP backend were exercised without a model. Live provider tool selection, end-to-end conversational generation, and browser visual inspection were not verified. Restart the backend to load the changed tools and grading route; rebuild or reload the Flutter client to load the player.
