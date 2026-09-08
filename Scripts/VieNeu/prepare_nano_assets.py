#!/usr/bin/env python3
"""Verify the pinned Nano bundle, or restore it with --download (stdlib only)."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zipfile

REPOSITORY = Path(__file__).resolve().parents[2]
ASSETS = REPOSITORY / "Letter/Shared/Data/Sources/Data/Resources/OfflineSpeechModels/vieneu-v3-nano"


def convert_constants():
    """Losslessly re-encode the two float32 preset-inference tensors as JSON."""
    result = {}
    with zipfile.ZipFile(ASSETS / "constants.npz") as archive:
        for name in ("null_spk", "null_style"):
            contents = archive.read(name + ".npy")
            if contents[:6] != b"\x93NUMPY" or contents[6] not in (1, 2, 3):
                raise ValueError("Unsupported NPY version")
            width = 2 if contents[6] == 1 else 4
            start = 8 + width
            length = int.from_bytes(contents[8:start], "little")
            header = ast.literal_eval(contents[start:start + length].decode())
            if header["descr"] != "<f4" or header["fortran_order"]:
                raise ValueError("Expected C-contiguous little-endian float32")
            raw = contents[start + length:]
            values = list(struct.unpack("<" + "f" * (len(raw) // 4), raw))
            result[name] = {"shape": list(header["shape"]), "data": values}
    return (json.dumps(result, separators=(",", ":")) + "\n").encode()


def source_url(name, manifest):
    model = manifest["model_revision"]
    sdk = manifest["sdk_revision"]
    github = f"https://raw.githubusercontent.com/pnnbao97/VieNeu-TTS/{sdk}"
    if name == "voices_v3_nano.json":
        return f"{github}/src/vieneu/assets/{name}"
    if name == "LICENSE-APACHE-2.0":
        return f"{github}/LICENSE"
    return f"https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Nano/resolve/{model}/{name}"


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(block)
    return checksum.hexdigest()


def restore(name, expected, manifest):
    target = ASSETS / name
    if target.exists() and digest(target) == expected:
        return
    with tempfile.TemporaryDirectory(prefix="letter-nano-") as folder:
        temporary = Path(folder) / name
        if name == "constants.json":
            temporary.write_bytes(convert_constants())
        else:
            subprocess.run(["curl", "-L", "--fail", "--retry", "3",
                            source_url(name, manifest), "-o", str(temporary)], check=True)
        if digest(temporary) != expected:
            raise ValueError(f"Checksum mismatch for {name}; bundle unchanged")
        # Both paths can be on different volumes; copy only verified bytes.
        target.write_bytes(temporary.read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true", help="Restore missing/corrupt pinned assets")
    args = parser.parse_args()
    manifest = json.loads((ASSETS / "checksums.json").read_text())
    names = [name for name in manifest["files"] if name != "constants.json"] + ["constants.json"]
    for name in names:
        expected = manifest["files"][name]
        if args.download:
            restore(name, expected, manifest)
        if digest(ASSETS / name) != expected:
            raise ValueError(f"Checksum mismatch: {name}")
    if convert_constants() != (ASSETS / "constants.json").read_bytes():
        raise ValueError("Converted constants differ from original NPZ tensors")
    print(f"Verified {len(names)} pinned Nano assets and lossless constants conversion")


if __name__ == "__main__":
    main()
