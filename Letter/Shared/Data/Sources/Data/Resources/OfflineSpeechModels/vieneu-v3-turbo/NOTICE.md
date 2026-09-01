# VieNeu v3 Turbo resource provenance

The files in this directory are redistributed under Apache License 2.0.
`LICENSE-APACHE-2.0` is included beside them.

## VieNeu model assets

- Project: `pnnbao-ump/VieNeu-TTS-v3-Turbo`
- Source: https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo
- Pinned ONNX INT8 revision: `62ee74b1c854741a1d8a1679b6bbd19b2fc29348`
- Author: Phạm Nguyễn Ngọc Bảo
- Bundled paths: `config.json`, `tokenizer.json`, and `onnx/*`

## Preset voices

- Project: `lastudio-community/VieNeu-TTS-v3-Turbo-CPP`
- Source: https://huggingface.co/lastudio-community/VieNeu-TTS-v3-Turbo-CPP
- Pinned revision: `a7b4f40050d4ff6d5225d8fd4fe6d571913844a2`
- Bundled path: `voices_v3_turbo.json`

## MOSS audio tokenizer

- Project: `OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX`
- Source: https://huggingface.co/OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX
- Pinned revision: `ceff0d0749bfb3fa2d61149794ec6feef0d1e1ae`
- Bundled paths: `codec/*`

## SEA-G2P

- Project: `pnnbao97/sea-g2p`
- Source: https://github.com/pnnbao97/sea-g2p
- Pinned C ABI revision: `05618a59deb5c97380d08609be3dec7e0bc27cca`
- Bundled path: `sea_g2p.bin`
- Native library: `VieNeuRuntime/Artifacts/SeaG2P.xcframework`

## SHA-256

```text
0fbbafe3fd4afa2a019af5c5ced204af6e2d1db044fa40f021525d2aee95b4ac  codec/moss_audio_tokenizer_decode_full.onnx
e69d52e0f4e84ca27850557ee54face46632d3a5a16c89bd246c7c408466dcad  codec/moss_audio_tokenizer_decode_shared.data
9527c86a29e1837edec1f74db57d5eeaadb3a715af3382703566460afed25855  codec/moss_audio_tokenizer_decode_step.onnx
3e291c883bb7d11ff2fe8e964e3e495519760358859f35c951254c7741592731  codec/codec_browser_onnx_meta.json
a9f8d9c4b4736448ab355d1a98cfe48f5e39aecf2916c37b0806c228612e9a2d  config.json
8f2d7306a35c6128793838f39c4c2da2c176e243bd63f0963c56bbf0376c3939  onnx/vieneu_acoustic_cached.onnx
429bfddd585b7a1907c7c9c944b3d91bc4da8b91f1f9982353351357140fd08f  onnx/vieneu_backbone_shared.data
8346ce8fefa3635a2dcd29b6f8a5cb23c7acfd5da9dfad54090b0f9b797c4b5a  onnx/vieneu_decode_step.onnx
bc45488bd7802cd0e5d65cc427e9124e1a15b8b7e9fd86d37a3d16f1e847de4d  onnx/vieneu_prefill.onnx
19ee6dd56530d7842c81fbd855f3d89440e2c3121e11f7e6ced447a559da585a  onnx/vieneu_v3_heads.npz
6cc6bcbe380b8c37bd9f2514e37c5dfa3e00e122c6e3125dae5c4afe48e39158  tokenizer.json
9f5ed60eb0be6af3447b097d1a5bfb90214d4292e83dd4f2e123e2b27896a02d  voices_v3_turbo.json
1495588cabe23376400239625b8c020666d894de5d6c5b67e1d93207441de440  sea_g2p.bin
```
