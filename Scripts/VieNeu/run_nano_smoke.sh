#!/bin/bash
# Usage: bash Scripts/VieNeu/run_nano_smoke.sh DERIVED_DATA BOOTED_SIMULATOR_UUID
# Build Letter for iphonesimulator first; this reuses its compiled native target.
set -euo pipefail
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 DERIVED_DATA BOOTED_SIMULATOR_UUID" >&2
    exit 2
fi
NANO_REPOSITORY=$(cd "$(dirname "$0")/../.." && pwd)
NANO_RUNTIME="${VIENEU_RUNTIME_PATH:-$1/SourcePackages/checkouts/iOSVieNeuRuntime}"
NANO_PRODUCTS="$1/Build/Products/Debug-iphonesimulator"
NANO_SIMULATOR="$2"
NANO_OUTPUT=$(mktemp -d "${TMPDIR:-/tmp}/letter-nano-check.XXXXXX")
NANO_RESOURCES="$NANO_REPOSITORY/Letter/Shared/Data/Sources/Data/Resources/OfflineSpeechModels"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcrun --sdk iphonesimulator clang++ -std=c++17 -O2 \
    -target "$(uname -m)-apple-ios26.0-simulator" \
    -I "$NANO_RUNTIME/Sources/CVieNeuNanoRuntime/include" \
    "$NANO_REPOSITORY/Scripts/VieNeu/nano_smoke.cpp" \
    "$NANO_PRODUCTS/CVieNeuNanoRuntime.o" "$NANO_PRODUCTS/libsea_g2p_rs_sim.a" \
    -F "$NANO_PRODUCTS" -framework onnxruntime -framework Foundation \
    -framework CoreML -framework Accelerate -o "$NANO_OUTPUT/nano-smoke"
xcrun simctl spawn "$NANO_SIMULATOR" "$NANO_OUTPUT/nano-smoke" \
    "$NANO_RESOURCES/vieneu-v3-nano" "$NANO_RESOURCES/vieneu-v3-turbo/sea_g2p.bin" "$NANO_OUTPUT"
echo "Sample WAV files: $NANO_OUTPUT"
