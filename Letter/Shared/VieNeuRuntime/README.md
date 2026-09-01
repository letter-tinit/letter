# VieNeuRuntime

This package is Letter's native iOS boundary for the VieNeu v3 Turbo ONNX
runtime. It exposes a small C ABI so Data can adapt it to
`LocalSpeechSynthesizing` without leaking C++ or ONNX Runtime into playback.

The first integration slice intentionally supports preset voices only. It does
not include the CLI, server, Python SDK, denoiser, reference encoder, voice
cloning, llama.cpp, GGML, or OpenMP.

The files under `Sources/CVieNeuRuntime/Vendor/vieneu` are derived from
`dduongtrandai/VieNeu-TTS.cpp` revision
`838979faf0354ffb3dff898e30b709f644fa7db4`. Its license is retained under
`ThirdPartyLicenses`.

`VieNeuRuntime` owns only the native inference boundary. Model selection,
resource lookup, audio encoding, and playback remain in Data. The C ABI accepts
a preset voice identifier, so exposing another bundled preset does not require
changing the C++ inference implementation.

The vendored runtime was reduced to the ONNX preset-voice path and adapted for
the model's dynamic local-layer count and speaker embedding projection. Letter
bundles the SEA-G2P C ABI from `pnnbao97/sea-g2p` revision
`05618a59deb5c97380d08609be3dec7e0bc27cca` as an iOS XCFramework. This restores
the text normalization and Vietnamese/English phonemization pipeline used to
train VieNeu; the former rule-based fallback remains only as initialization
failure recovery. The runtime still excludes reference-audio encoding, voice
cloning, and streaming output.
