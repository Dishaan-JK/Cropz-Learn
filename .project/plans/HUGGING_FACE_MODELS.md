# Hugging Face local models

Requested 2026-10-19. User selected Ollama as the runtime.

## Contract

Settings → AI & models must inspect public Hugging Face GGUF repositories and exact file sizes, detect the backend host's CPU, RAM and NVIDIA/AMD/Intel graphics, assess memory headroom and likely execution difficulty before allowing a download, show cancellable progress, test the downloaded model, and configure it for Lumi only after successful loading and tool calling. GPU discovery must not be presented as proof of GPU execution; runtime allocation is reported separately. No guaranteed utilisation percentage or trouble-free claim is possible before inference.

## Impact and boundaries

- Backend: new Linux hardware probe and local model manager; new settings/model endpoints. Hugging Face metadata access uses a fixed HTTPS host. Ollama calls use a configured loopback-only endpoint. No model code or shell command from a repository is executed.
- Client: new HTTP methods and model-download settings panel; existing API-provider controls remain.
- Storage: background job state under LUMI_DATA_DIR; weights remain Ollama-owned. A generated Ollama alias pins context/execution options. Existing provider settings change only after successful verification and activation, using the current restart boundary.
- Compatibility: public, single-file GGUF text/chat checkpoints initially. Gated/private files, split shards, projector files and embedding-only models are rejected. Unsupported probing platforms fail closed with an explanation.
- Recovery: cancellation stops the client pull stream and prevents activation; Ollama may retain reusable partial blobs. Failed checks preserve the previous provider. Interrupted jobs are marked interrupted on restart; retry can reuse Ollama's existing blobs. No automatic package/driver installation or changes to an existing Ollama daemon.

## Delivery sequence

1. Hardware inventory and conservative compatibility estimates, including OS headroom, file size, context cache and runtime overhead.
2. Hub inspection, exact-file download, progress/cancellation, runtime and tool-call checks, and provider activation.
3. Settings integration and regression tests for CPU-only, NVIDIA, AMD, Intel shared memory, constrained memory, cancellation, failed checks and activation.
4. Static analysis, complete tests, web build, actual host inventory/metadata checks, and bounded local-runtime evidence where available.

## Limits

Estimates are conditional on the selected context and current load. Report unknown GPU metrics explicitly; shared GPU RAM is never added to physical RAM. Live runtime checks remain separate from mocked tests. Changing the active model does not convert old conversation context into a benchmark of model quality.

## Completed implementation

Hardware probing, public GGUF inspection, current-resource admission, exact-file
SHA-256 checks where available, progress/cancellation, runtime checks, atomic
provider activation/recovery, and Settings integration are implemented. Unknown
disk telemetry is reported as a warning; known insufficient disk capacity blocks
the pull. The live Ollama service enforces actual disk capacity. Detailed memory
metadata discovered after download can increase the KV-cache requirement before
inference, preventing a provisional estimate from admitting a larger known cache.

Verification and scope limits are recorded in ../qa/HUGGING_FACE_MODELS.md.
