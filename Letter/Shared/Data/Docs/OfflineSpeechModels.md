# Offline speech models

Local speech playback does not depend on sherpa-onnx, VieNeu, or a specific
voice. `LocalSpeechSynthesizing` is the Data-layer boundary used by the
playback engine. `OfflineSpeechSynthesizerRouter` resolves the selected model
and keeps language routing out of playback.

The composition root creates each synthesizer once. Engines are lazy: saving
an offline model in Speech Provider settings calls `prepare`, and later book
playback reuses that same in-memory engine. Closing the settings sheet does not
own or unload model state.

Sherpa model registration is data-driven through
`Sources/Data/Resources/OfflineSpeechModels/models.json`. VieNeu uses its own
native ONNX adapter because its inference pipeline is not a sherpa model
family; its pinned resources and checksums are documented in
the SDK’s `ModelResources/vieneu-v3-turbo/NOTICE.md`.

## Add a model from a supported family

1. Copy the model files into `OfflineSpeechModels`.
2. Add one entry to `models.json`.
3. Set `languageCodes` and mark the preferred entry for that language with
   `isDefault: true`.
4. Specify only paths relative to the `OfflineSpeechModels` directory.
5. Build the app. The catalog validates IDs, required keys, safe paths, and
   resource existence when it is loaded.

The supported families and required `files` keys are:

| Family | Required keys |
| --- | --- |
| `vits` | `model`, `tokens` |
| `matcha` | `acousticModel`, `vocoder`, `tokens` |

Optional paths such as `dataDir`, `lexicon`, and `dictDir` also belong in
`files`. Numeric family settings such as `noiseScale`, `noiseScaleW`, and
`lengthScale` belong in `parameters`.

Entries that reference the same family, files, parameters, thread
count, and sentence batch size share one loaded engine. This allows multiple
speaker IDs from a multi-speaker model without loading its weights repeatedly.

Adding a family that sherpa-onnx does not currently support requires a new
adapter implementing `LocalSpeechSynthesizing`, one model registration in the
offline router/composition root, and a stable settings identifier in Domain.
Playback, checkpoints, media controls, and book imports remain unchanged.

## VieNeu v3 Nano

Select **VieNeu v3 Nano (Preview)** in the Vietnamese offline model picker in
Speech Provider settings. Existing Turbo selections and voice preferences are
preserved. Nano has its own 11-voice catalog, defaulting to Adam, and participates
in the existing settings/backup flow through its `vieNeuV3Nano` identifier.

`AppContainer` injects `VieNeuNanoSpeechSynthesizer` into the existing router.
Domain contains only the model/voice identifiers; the presentation layer owns
the localized label. Native ONNX tensors, G2P, model paths, cancellation and
waveform encoding remain in Data and the narrow `CVieNeuNanoRuntime` target.
The native runtime belongs to the separate `iOSVieNeuRuntime` repository, version
1.2.1, exposing both Turbo and Nano products. Data pins the GitHub dependency
`git@github.com:letter-tinit/iOSVieNeuRuntime.git` to `exact: "1.2.1"`.
The smoke script uses the runtime checkout in the supplied DerivedData directory;
set `VIENEU_RUNTIME_PATH` only to test a different checkout.
Data also depends on the optional `VieNeuNanoModels` and `VieNeuTurboModels`
products. Their URL accessors locate model files in embedded resource frameworks;
Nano and Turbo share one SEA-G2P dictionary framework. Letter contains neither
VieNeu model files nor native runtime sources. No model copies or downloads occur
at runtime, and engine creation remains lazy.

Nano uses four ONNX graphs, one CPU thread with spinning disabled, 8 Euler
steps with the upstream sway=-1 schedule, CFG 3 and mono 24 kHz PCM. It uses the existing non-streaming playback
path, which prefetches two chunks for Nano to absorb differences in sentence duration.
Other models retain their one-chunk lookahead. This bounded buffer cannot
compensate for sustained generation slower than the selected playback rate.
The chunk limit is 120 UTF-16 units to leave room for the shared chunker's short
tail merge under Nano's 140-scalar limit. The adapter normalizes text to NFC.
Playback rate remains a player setting, consistent with the existing engines.

Pinned resources, licenses, checksums and restoration instructions are in
the SDK’s `ModelResources/` directory and model-resource release archives.
The runtime never silently falls back to another model after a failed request.

### Verification

- Build Letter for iOS Simulator and iPhone (`CODE_SIGNING_ALLOWED=NO` is sufficient).
- Use the SDK’s `Scripts/verify_model_resources.py` against the built app.
- The SDK’s `Scripts/prepare_nano_assets.py MODEL_DIRECTORY` verifies or restores a Nano input bundle.
- `Scripts/VieNeu/nano_smoke.cpp` exercises real bundled graphs: Vietnamese and
  mixed-language PCM, missing assets, invalid voice, cancellation before/during
  inference, and seeded output recovery. It is a standalone executable, not a
  new Xcode test target. See `Scripts/VieNeu/run_nano_smoke.sh` for execution.

Simulator timings are not iPhone thermal measurements. Device validation still
needs sustained book playback, pronunciation review (especially English names),
memory and thermal observation. Nano is an experimental model with no frame-level
streaming. The pre-existing oversized Turbo Swift adapter and Turbo phonemizer's
global configuration remain legacy debt; Nano does not reuse that global state.
