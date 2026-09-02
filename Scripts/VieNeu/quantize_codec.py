#!/usr/bin/env python3
"""Create VieNeu codec graphs with shared per-channel INT8 weights."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import onnx


GRAPH_NAMES = (
    "moss_audio_tokenizer_decode_full.onnx",
    "moss_audio_tokenizer_decode_step.onnx",
)
QUANTIZED_OPERATORS = ("MatMul",)
SHARED_WEIGHTS_NAME = "moss_audio_tokenizer_decode_int8_shared.data"
LIMITED_QUANTIZERS = 8


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
    return quantize_matmul_graph(
        source,
        destination,
        constant_weights_only=True,
    )


def quantize_matmul_graph(
    source: Path,
    destination: Path,
    *,
    constant_weights_only: bool,
) -> Path:
    from onnxruntime.quantization import QuantType, quantize_dynamic

    quantize_dynamic(
        source,
        destination,
        op_types_to_quantize=list(QUANTIZED_OPERATORS),
        per_channel=True,
        weight_type=QuantType.QInt8,
        use_external_data_format=True,
        extra_options={"MatMulConstBOnly": constant_weights_only},
    )
    return destination.with_suffix(destination.suffix + ".data")


def limited_graph_name(graph_name: str, quantizers: int) -> str:
    return graph_name.replace(".onnx", f"_rvq{quantizers}.onnx")


def attention_source_graph_name(graph_name: str) -> str:
    return f".{graph_name.removesuffix('.onnx')}_attention_int8.onnx"


def validate_attention_quantization(model_path: Path) -> None:
    model = onnx.load(model_path, load_external_data=False)
    remaining = [node.name for node in model.graph.node if node.op_type == "MatMul"]
    if remaining:
        raise RuntimeError(
            f"Unquantized MatMul nodes remain in {model_path.name}: {remaining}"
        )


def create_limited_graph(
    source: Path,
    destination: Path,
    quantizers: int,
) -> None:
    if not 1 <= quantizers < 16:
        raise ValueError("Limited codec graph requires 1...15 quantizers")
    model = onnx.load(source, load_external_data=False)
    full_sum = "/Add_15_output_0"
    limited_sum = (
        "/Add_output_0"
        if quantizers == 1
        else f"/Add_{quantizers - 1}_output_0"
    )
    available_outputs = {
        output
        for node in model.graph.node
        for output in node.output
    }
    if limited_sum not in available_outputs:
        raise RuntimeError(
            f"{source.name} has no RVQ prefix output {limited_sum}"
        )
    replacements = 0
    for node in model.graph.node:
        for index, input_name in enumerate(node.input):
            if input_name == full_sum:
                node.input[index] = limited_sum
                replacements += 1
    if replacements != 1:
        raise RuntimeError(
            f"Expected one full RVQ consumer in {source.name}, got {replacements}"
        )
    model = onnx.utils.Extractor(model).extract_model(
        [value.name for value in model.graph.input],
        [value.name for value in model.graph.output],
    )
    model.graph.name = f"{model.graph.name}_rvq{quantizers}"
    onnx.save_model(model, destination)
    onnx.checker.check_model(str(destination), full_check=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    arguments.output.mkdir(parents=True, exist_ok=True)

    weight_files = []
    temporary_graphs = []
    for graph_name in GRAPH_NAMES:
        weight_files.append(
            quantize_graph(
                arguments.source / graph_name,
                arguments.output / graph_name,
            )
        )
        attention_graph = arguments.output / attention_source_graph_name(
            graph_name
        )
        temporary_graphs.append(attention_graph)
        weight_files.append(
            quantize_matmul_graph(
                arguments.source / graph_name,
                attention_graph,
                constant_weights_only=False,
            )
        )
        limited_name = limited_graph_name(graph_name, LIMITED_QUANTIZERS)
        create_limited_graph(
            attention_graph,
            arguments.output / limited_name,
            LIMITED_QUANTIZERS,
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
        limited_name = limited_graph_name(graph_name, LIMITED_QUANTIZERS)
        limited_path = arguments.output / limited_name
        set_external_location(limited_path, SHARED_WEIGHTS_NAME)
        validate_graph(limited_path)
        validate_attention_quantization(limited_path)
    for path in temporary_graphs:
        path.unlink()
    for path in weight_files:
        path.unlink()

    metadata_path = arguments.source / "codec_browser_onnx_meta.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    external_files = metadata["external_data_files"]
    for graph_name in GRAPH_NAMES:
        external_files[graph_name] = [SHARED_WEIGHTS_NAME]
        external_files[
            limited_graph_name(graph_name, LIMITED_QUANTIZERS)
        ] = [SHARED_WEIGHTS_NAME]
    (arguments.output / metadata_path.name).write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
