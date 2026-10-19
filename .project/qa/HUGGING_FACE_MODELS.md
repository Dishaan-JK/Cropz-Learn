# Hugging Face local model downloads

Implemented 2026-10-19. User selected Ollama as the runtime.

## Delivered behavior

Settings → AI & models contains a Hugging Face model panel. It inventories the
Linux backend host CPU, available/total RAM and container RAM limits, and
NVIDIA/AMD/Intel graphics. It distinguishes dedicated GPU memory from shared or
unknown memory and reports missing utilisation telemetry as unavailable.

The flow inspects public GGUF files, checks current RAM/headroom/context and
known disk/VRAM budgets, then admits a cancellable background Ollama pull. It
rechecks the remote file identity and current resources before starting. Where
Hugging Face supplies an LFS SHA-256, the matching Ollama model layer must be
observed before loading. Known transformer attention metadata can increase the
cache budget after download and before inference.

A context-bound Ollama alias is created. The worker verifies chat/tool support,
a real tool call through /v1/chat/completions, reported residency, requested
execution mode and post-load memory headroom. CPU-only and GPU-required modes
reject an unexpected execution path. Auto mode reports CPU fallback explicitly.
The bounded test model is unloaded unless it was already resident beforehand.

After success, the settings page automatically activates the alias using the
existing provider restart/reconnect boundary. Atomic provider writes, an
activation-intent recovery record, and a provider fingerprint preserve the
previous configuration on failed verification/writes and protect a newer manual
provider choice. Job progress persists locally; interrupted jobs require another
compatibility check. Completed pending activation resumes when the page opens.

## Validation

- Static analysis: no issues.
- Complete Flutter suite: 98 tests passed.
- API regression script: 17 assertions passed.
- Workspace regression script: 24 assertions passed.
- Release web build: passed. The previously observed Cupertino icon font warning
  remains; this change did not introduce that dependency.
- New coverage includes CPU/NVIDIA/AMD/shared-Intel budgets, hardware fixtures,
  zero free VRAM, container RAM limits, large KV caches, file-hash mismatches,
  memory changes before admission, cancellation, interrupted jobs, unsupported
  tool capability, failed tool output, GPU/CPU mismatch, atomic write failure,
  protection of newer connection settings, fresh-RAM validation when activating a
  completed job, and activation-intent recovery.
- Settings widget tests at 390px and 1180px verify blocked downloads and successful
  download-to-auto-configuration interactions without layout overflow.

Live evidence: [hugging-face-live-smoke.log](hugging-face-live-smoke.log).
Test output: [hugging-face-tests.log](hugging-face-tests.log).

The live smoke used Qwen/Qwen2.5-0.5B-Instruct-GGUF, exact file
qwen2.5-0.5b-instruct-q4_k_m.gguf (491400032 bytes), revision
9217f5db79a29953eb74d5343926648285ec7e67, SHA-256
74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db.
The real pull, file-hash verification, OpenAI-compatible tool call, disposable
provider save, and startup of a temporary real Lumi backend with that saved
model all passed. The actual HTTP routes restored configured job state,
returned host hardware, and rejected an unchecked download with HTTP 400.
The temporary server was stopped afterwards. The user's real Lumi provider
configuration was not changed. The downloaded HF model and lumi-hf alias remain
in Ollama, and the test model was unloaded after verification.

The host is Intel Core Ultra 5 235U, 14 logical processors, approximately 30.77 GiB
RAM, and Intel Arrow Lake-U integrated graphics using i915. Ollama 0.33.2 reported
CPU-only loading for this test: 577817803 bytes allocated, 86417771 bytes beyond
the GGUF file size, and zero GPU bytes. Intel GPU utilisation and protected
Ollama-store free space were unavailable to the backend user and were not
invented. Sampled CPU and system-RAM change are in the log and include other
activity. These timings and samples are exploratory, not a performance benchmark.

## Explicit limits

- Initial support is Linux host probing and public, ungated, root-level,
  single-file GGUF text/chat models via Ollama. It does not support arbitrary
  Safetensors/Transformers models, private/gated repositories, projector files,
  split shards or embedding-only models in this download flow.
- Hardware discovery is separate from runtime acceleration. NVIDIA and AMD
  paths have fixture coverage; they were not live-tested on physical devices.
  No Intel GPU acceleration was proven on this host; CPU fallback was observed.
- Memory estimates are admission guidance, not a trouble-free guarantee. The
  basic real tool-call test does not prove held-out task accuracy or full Lumi
  learning-task completion. Live browser rendering was not inspected.
- The page must be open (or reopened) to perform final activation/reconnection.
  Downloads and verification themselves continue in the backend.
- Progress is per current Ollama layer. Cancellation can leave reusable partial
  blobs, and downloaded aliases are retained for later manual use.
- Set LUMI_OLLAMA_MODELS_DIR to a readable actual daemon store for a disk precheck;
  otherwise unknown space is displayed and Ollama enforces capacity at pull time.
  LUMI_OLLAMA_URL must be a loopback service. No drivers or packages are installed.

## Impact alignment and release

Changes stay within backend hardware/model management, additive HTTP endpoints,
the client transport and AI settings widgets. Existing agent prompts/tools and
workspace storage formats were preserved. Provider persistence was strengthened
to an atomic write for safe activation. No new package dependency was added.

Restart the backend and reload the client to enable /api/local-models/*.
A previous provider can be restored through the existing connection settings.
No automatic deletion of model weights or partial downloads is performed.

References: [Hugging Face GGUF/Ollama](https://huggingface.co/docs/hub/en/ollama),
[Ollama hardware support](https://docs.ollama.com/gpu),
[Ollama runtime allocation API](https://docs.ollama.com/api/ps).
