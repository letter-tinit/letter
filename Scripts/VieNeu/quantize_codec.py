#!/usr/bin/env python3
"""Create per-channel INT8 VieNeu codec graphs with shared external weights."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import onnx
from onnxruntime.quantization import QuantType, quantize_dynamic


GRAPH_NAMES = (
    "moss_audio_tokenizer_decode_step.onnx",
    "moss_audio_tokenizer_decode_full.onnx",
)
QUANTIZED_OPERATORS = ("MatMul",)
SHARED_WEIGHTS_NAME = "moss_audio_tokenizer_decode_int8_shared.data"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def set_external_location(model_path: Path, location: str) -> None:
    model = onnx.load(model_path, load_external_data=False)
    external_count = 0
    for initializer in model.graph.initializer:
        if initializer.data_location != onnx.TensorProto.EXTERNAL:
            continue
        for entry in initializer.external_data:
            if entry.key == "location":
                entry.value = location
                external_count += 1
                break
    if external_count == 0:
        raise RuntimeError(f"No external tensors found in {model_path.name}")
    onnx.save_model(model, model_path)


def validate_graph(model_path: Path) -> None:
    model = onnx.load(model_path, load_external_data=False)
    locations = {
        entry.value
        for initializer in model.graph.initializer
        if initializer.data_location == onnx.TensorProto.EXTERNAL
        for entry in initializer.external_data
        if entry.key == "location"
    }
    if locations != {SHARED_WEIGHTS_NAME}:
        raise RuntimeError(
            f"Unexpected external data in {model_path.name}: {sorted(locations)}"
        )
    onnx.checker.check_model(str(model_path), full_check=False)


def quantize_graph(source: Path, destination: Path) -> Path:
    quantize_dynamic(
        source,
        destination,
        op_types_to_quantize=list(QUANTIZED_OPERATORS),
        per_channel=True,
        weight_type=QuantType.QInt8,
        use_external_data_format=True,
        extra_options={"MatMulConstBOnly": True},
    )
    return destination.with_suffix(destination.suffix + ".data")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    arguments.output.mkdir(parents=True, exist_ok=True)

    weight_files = []
    for graph_name in GRAPH_NAMES:
        weight_files.append(
            quantize_graph(
                arguments.source / graph_name,
                arguments.output / graph_name,
            )
        )
    hashes = {sha256(path) for path in weight_files}
    if len(hashes) != 1:
        raise RuntimeError("Codec graphs did not produce identical shared weights")

    shared_weights = arguments.output / SHARED_WEIGHTS_NAME
    shutil.copyfile(weight_files[0], shared_weights)
    for graph_name in GRAPH_NAMES:
        graph_path = arguments.output / graph_name
        set_external_location(graph_path, SHARED_WEIGHTS_NAME)
        validate_graph(graph_path)
    for path in weight_files:
        path.unlink()

    metadata_path = arguments.source / "codec_browser_onnx_meta.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    external_files = metadata["external_data_files"]
    for graph_name in GRAPH_NAMES:
        external_files[graph_name] = [SHARED_WEIGHTS_NAME]
    (arguments.output / metadata_path.name).write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
