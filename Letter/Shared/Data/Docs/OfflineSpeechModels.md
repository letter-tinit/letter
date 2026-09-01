# Offline speech models

Local speech playback does not depend on sherpa-onnx or a specific voice. The
`LocalSpeechSynthesizing` protocol is the boundary used by the playback engine.
Sherpa model registration is data-driven through
`Sources/Data/Resources/OfflineSpeechModels/models.json`.

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
adapter implementing `LocalSpeechSynthesizing`; playback, checkpoints, media
controls, and book imports remain unchanged.
