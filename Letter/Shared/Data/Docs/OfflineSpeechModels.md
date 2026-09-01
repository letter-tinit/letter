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
`vieneu-v3-turbo/NOTICE.md`.

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
| `kokoro` | `model`, `voices`, `tokens` |
| `kitten` | `model`, `voices`, `tokens` |
| `zipvoice` | `tokens`, `encoder`, `decoder`, `vocoder` |
| `pocket` | `lmFlow`, `lmMain`, `encoder`, `decoder`, `textConditioner`, `vocabJson`, `tokenScoresJson` |
| `supertonic` | `durationPredictor`, `textEncoder`, `vectorEstimator`, `vocoder`, `ttsJson`, `unicodeIndexer`, `voiceStyle` |

Optional paths such as `dataDir`, `lexicon`, and `dictDir` also belong in
`files`. String configuration such as Kokoro's `lang` belongs in `options`.
Numeric family settings such as `noiseScale`, `lengthScale`, and
`guidanceScale` belong in `parameters`.

Entries that reference the same family, files, options, parameters, thread
count, and sentence batch size share one loaded engine. This allows multiple
speaker IDs from a multi-speaker model without loading its weights repeatedly.

Adding a family that sherpa-onnx does not currently support requires a new
adapter implementing `LocalSpeechSynthesizing`, one model registration in the
offline router/composition root, and a stable settings identifier in Domain.
Playback, checkpoints, media controls, and book imports remain unchanged.
