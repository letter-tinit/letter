#include "../vieneu_v3_onnx.h"
#include "vieneu_v3_onnx_internal.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <limits>
#include <numeric>
#include <vector>
#include <string>
#include <stdexcept>

// --- VieneuV3OnnxEngine Audio Member Functions ---

bool VieneuV3OnnxEngine::read_wav_file(const std::string& path, WavData& wav, std::string& error) const {
    wav = WavData{};
    try {
        const std::string bytes = read_file_bytes(path);
        const auto* data = reinterpret_cast<const uint8_t*>(bytes.data());
        const size_t size = bytes.size();
        if (size < 44 || std::memcmp(data, "RIFF", 4) != 0 || std::memcmp(data + 8, "WAVE", 4) != 0) {
            error = "Reference audio must be a RIFF/WAVE file: " + path;
            return false;
        }

        uint16_t audio_format = 0;
        uint16_t channels = 0;
        uint32_t sample_rate = 0;
        uint16_t bits_per_sample = 0;
        const uint8_t* pcm = nullptr;
        size_t pcm_size = 0;
        size_t off = 12;
        while (off + 8 <= size) {
            const char* id = reinterpret_cast<const char*>(data + off);
            const uint32_t chunk_size = read_u32_le(data + off + 4);
            const size_t payload = off + 8;
            if (payload + chunk_size > size) {
                error = "Truncated WAV chunk in reference audio: " + path;
                return false;
            }
            if (std::memcmp(id, "fmt ", 4) == 0) {
                if (chunk_size < 16) {
                    error = "Invalid WAV fmt chunk in reference audio: " + path;
                    return false;
                }
                audio_format = read_u16_le(data + payload);
                channels = read_u16_le(data + payload + 2);
                sample_rate = read_u32_le(data + payload + 4);
                bits_per_sample = read_u16_le(data + payload + 14);
            } else if (std::memcmp(id, "data", 4) == 0) {
                pcm = data + payload;
                pcm_size = chunk_size;
            }
            off = payload + chunk_size + (chunk_size & 1u);
        }

        if (!pcm || pcm_size == 0 || channels == 0 || sample_rate == 0 || bits_per_sample == 0) {
            error = "Reference WAV is missing fmt/data chunks: " + path;
            return false;
        }
        if (audio_format != 1 && audio_format != 3) {
            error = "Reference WAV must be PCM or IEEE-float format: " + path;
            return false;
        }
        const size_t bytes_per_sample = bits_per_sample / 8;
        if (bytes_per_sample == 0 || pcm_size < bytes_per_sample * channels) {
            error = "Reference WAV has invalid sample size: " + path;
            return false;
        }

        const size_t frames = pcm_size / (bytes_per_sample * channels);
        wav.sample_rate = static_cast<int>(sample_rate);
        wav.channels = static_cast<int>(channels);
        wav.samples.resize(frames * channels);
        for (size_t i = 0; i < frames * channels; ++i) {
            const uint8_t* p = pcm + i * bytes_per_sample;
            float v = 0.0f;
            if (audio_format == 3 && bits_per_sample == 32) {
                std::memcpy(&v, p, sizeof(float));
            } else if (audio_format == 1 && bits_per_sample == 16) {
                v = static_cast<float>(read_i16_le(p)) / 32768.0f;
            } else if (audio_format == 1 && bits_per_sample == 24) {
                v = static_cast<float>(read_i24_le(p)) / 8388608.0f;
            } else if (audio_format == 1 && bits_per_sample == 32) {
                v = static_cast<float>(read_i32_le(p)) / 2147483648.0f;
            } else if (audio_format == 1 && bits_per_sample == 8) {
                v = (static_cast<float>(*p) - 128.0f) / 128.0f;
            } else {
                error = "Unsupported reference WAV sample format: " + path;
                return false;
            }
            wav.samples[i] = std::clamp(v, -1.0f, 1.0f);
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("Failed to read reference WAV: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::encode_reference_audio(
    const std::string& path,
    std::vector<int64_t>& out_codes,
    std::string& error) {
    out_codes.clear();
    WavData wav;
    if (!read_wav_file(path, wav, error)) {
        return false;
    }

    const int target_sr = sample_rate();
    const int64_t in_frames = static_cast<int64_t>(wav.samples.size() / wav.channels);
    const int64_t out_frames = wav.sample_rate == target_sr
        ? in_frames
        : static_cast<int64_t>(std::llround(static_cast<double>(in_frames) * target_sr / wav.sample_rate));
    if (out_frames <= 0) {
        error = "Reference WAV contains no samples: " + path;
        return false;
    }

    std::vector<float> stereo(static_cast<size_t>(2 * out_frames), 0.0f);
    for (int64_t i = 0; i < out_frames; ++i) {
        const double src_pos = wav.sample_rate == target_sr
            ? static_cast<double>(i)
            : static_cast<double>(i) * wav.sample_rate / target_sr;
        const int64_t i0 = (std::min)(static_cast<int64_t>(std::floor(src_pos)), in_frames - 1);
        const int64_t i1 = (std::min)(i0 + 1, in_frames - 1);
        const float frac = static_cast<float>(src_pos - static_cast<double>(i0));
        for (int c = 0; c < 2; ++c) {
            const int src_c = wav.channels == 1 ? 0 : (std::min)(c, wav.channels - 1);
            const float a = wav.samples[static_cast<size_t>(i0 * wav.channels + src_c)];
            const float b = wav.samples[static_cast<size_t>(i1 * wav.channels + src_c)];
            stereo[static_cast<size_t>(c * out_frames + i)] = a + (b - a) * frac;
        }
    }

    try {
        if (!codec_encode_session_) {
            if (!load_session(codec_encode_path_, codec_encode_session_, error)) {
                return false;
            }
            cache_session_io(*codec_encode_session_, codec_encode_io_);
        }
        Ort::MemoryInfo& mem = cpu_memory_info();
        if (codec_encode_io_.input_names.size() != 2 || codec_encode_io_.output_names.empty()) {
            error = "MOSS codec encode ONNX signature mismatch: expected 2 inputs and at least 1 output.";
            return false;
        }

        std::vector<int32_t> lengths = {static_cast<int32_t>(out_frames)};
        std::vector<int64_t> wav_shape = {1, 2, out_frames};
        std::vector<int64_t> len_shape = {1};
        std::vector<Ort::Value> inputs;
        inputs.emplace_back(Ort::Value::CreateTensor<float>(mem, stereo.data(), stereo.size(), wav_shape.data(), wav_shape.size()));
        inputs.emplace_back(Ort::Value::CreateTensor<int32_t>(mem, lengths.data(), lengths.size(), len_shape.data(), len_shape.size()));
        auto out = codec_encode_session_->Run(
            Ort::RunOptions{nullptr},
            codec_encode_io_.input_ptrs.data(),
            inputs.data(),
            inputs.size(),
            codec_encode_io_.output_ptrs.data(),
            codec_encode_io_.output_ptrs.size());
        const std::vector<int64_t> shape = tensor_shape(out[0]);
        if (shape.size() != 3) {
            error = "MOSS codec encode returned unexpected rank.";
            return false;
        }

        size_t count = 1;
        for (int64_t dim : shape) {
            count *= static_cast<size_t>(dim);
        }
        std::vector<int64_t> raw(count);
        const auto type = out[0].GetTensorTypeAndShapeInfo().GetElementType();
        if (type == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64) {
            const int64_t* p = out[0].GetTensorData<int64_t>();
            raw.assign(p, p + count);
        } else if (type == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32) {
            const int32_t* p = out[0].GetTensorData<int32_t>();
            for (size_t i = 0; i < count; ++i) {
                raw[i] = p[i];
            }
        } else {
            error = "MOSS codec encode returned non-integer codes.";
            return false;
        }

        if (shape[0] == 1 && shape[2] == config_.n_vq) {
            out_codes = std::move(raw);
        } else if (shape[0] == config_.n_vq && shape[1] == 1) {
            const int64_t frames = shape[2];
            out_codes.resize(static_cast<size_t>(frames * config_.n_vq));
            for (int ch = 0; ch < config_.n_vq; ++ch) {
                for (int64_t t = 0; t < frames; ++t) {
                    out_codes[static_cast<size_t>(t * config_.n_vq + ch)] =
                        raw[static_cast<size_t>(ch * frames + t)];
                }
            }
        } else if (shape[0] == 1 && shape[1] == config_.n_vq) {
            const int64_t frames = shape[2];
            out_codes.resize(static_cast<size_t>(frames * config_.n_vq));
            for (int ch = 0; ch < config_.n_vq; ++ch) {
                for (int64_t t = 0; t < frames; ++t) {
                    out_codes[static_cast<size_t>(t * config_.n_vq + ch)] =
                        raw[static_cast<size_t>(ch * frames + t)];
                }
            }
        } else {
            error = "MOSS codec encode returned unsupported code shape.";
            return false;
        }
        return !out_codes.empty();
    } catch (const std::exception& e) {
        error = std::string("MOSS codec encode failed: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::decode_codes(const std::vector<int32_t>& frames, int64_t frame_count, std::vector<float>& out_audio, std::string& error) {
    try {
        if (!codec_decode_session_) {
            if (!load_session(codec_decode_path_, codec_decode_session_, error)) {
                return false;
            }
            cache_session_io(*codec_decode_session_, codec_decode_io_);
        }
        std::vector<int32_t> lengths = {static_cast<int32_t>(frame_count)};
        std::vector<int64_t> codes_shape = {1, frame_count, config_.n_vq};
        std::vector<int64_t> len_shape = {1};
        Ort::MemoryInfo& mem = cpu_memory_info();
        if (codec_decode_io_.input_names.size() != 2 || codec_decode_io_.output_names.empty()) {
            error = "MOSS codec decode ONNX signature mismatch: expected 2 inputs and at least 1 output.";
            return false;
        }
        std::vector<Ort::Value> inputs;
        inputs.emplace_back(Ort::Value::CreateTensor<int32_t>(mem, const_cast<int32_t*>(frames.data()), frames.size(), codes_shape.data(), codes_shape.size()));
        inputs.emplace_back(Ort::Value::CreateTensor<int32_t>(mem, lengths.data(), lengths.size(), len_shape.data(), len_shape.size()));
        const Ort::RunOptions run_options{nullptr};
        const auto decode_start = benchmark_enabled_ ? std::chrono::steady_clock::now() : std::chrono::steady_clock::time_point{};
        auto out = codec_decode_session_->Run(
            run_options,
            codec_decode_io_.input_ptrs.data(),
            inputs.data(),
            inputs.size(),
            codec_decode_io_.output_ptrs.data(),
            codec_decode_io_.output_ptrs.size());
        if (benchmark_enabled_) {
            const auto decode_end = std::chrono::steady_clock::now();
            benchmark_stats_.codec_decode_ms += std::chrono::duration<double, std::milli>(decode_end - decode_start).count();
            benchmark_stats_.codec_decode_calls += 1;
        }
        const std::vector<int64_t> shape = tensor_shape(out[0]);
        const float* audio_data = out[0].GetTensorData<float>();
        if (shape.size() == 3 && shape[0] == 1) {
            const int64_t channels = shape[1];
            const int64_t samples = shape[2];
            out_audio.assign(static_cast<size_t>(samples), 0.0f);
            for (int64_t c = 0; c < channels; ++c) {
                const float* src = audio_data + c * samples;
                for (int64_t i = 0; i < samples; ++i) out_audio[static_cast<size_t>(i)] += src[i] / static_cast<float>(channels);
            }
        } else {
            size_t count = 1;
            for (int64_t dim : shape) {
                count *= static_cast<size_t>(dim);
            }
            out_audio.assign(audio_data, audio_data + count);
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("MOSS codec decode failed: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::initialize_codec_stream_state(
    CodecStreamState& state,
    std::string& error
) {
    state = CodecStreamState{};
    if (!codec_stream_spec_.loaded || !codec_stream_session_) {
        error = "MOSS streaming codec is not initialized.";
        return false;
    }
    try {
        Ort::AllocatorWithDefaultOptions allocator;
        for (const auto& spec : codec_stream_spec_.state_tensors) {
            size_t count = 1;
            for (const int64_t dimension : spec.shape) {
                if (dimension <= 0 ||
                    count > std::numeric_limits<size_t>::max() /
                        static_cast<size_t>(dimension)) {
                    error = "MOSS streaming codec metadata has an invalid state shape.";
                    return false;
                }
                count *= static_cast<size_t>(dimension);
            }
            if (spec.data_type == CodecStreamDataType::float32) {
                Ort::Value value = Ort::Value::CreateTensor<float>(
                    allocator,
                    spec.shape.data(),
                    spec.shape.size()
                );
                std::fill_n(
                    value.GetTensorMutableData<float>(),
                    count,
                    0.0f
                );
                state.values.emplace(
                    spec.input_name,
                    std::move(value)
                );
            } else {
                Ort::Value value = Ort::Value::CreateTensor<int32_t>(
                    allocator,
                    spec.shape.data(),
                    spec.shape.size()
                );
                std::fill_n(
                    value.GetTensorMutableData<int32_t>(),
                    count,
                    spec.initial_int_value
                );
                state.values.emplace(
                    spec.input_name,
                    std::move(value)
                );
            }
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("Failed to initialize MOSS streaming codec state: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::decode_stream_frames(
    const std::vector<int32_t>& frames,
    int64_t frame_count,
    CodecStreamState& state,
    std::vector<float>& out_audio,
    std::string& error
) {
    out_audio.clear();
    if (frame_count <= 0 ||
        frames.size() != static_cast<size_t>(frame_count * config_.n_vq)) {
        error = "MOSS streaming codec received an invalid frame buffer.";
        return false;
    }
    if (state.values.empty() && !initialize_codec_stream_state(state, error)) {
        return false;
    }

    try {
        Ort::MemoryInfo& memory = cpu_memory_info();
        std::vector<int32_t> lengths = {static_cast<int32_t>(frame_count)};
        std::vector<int64_t> codes_shape = {1, frame_count, config_.n_vq};
        std::vector<int64_t> length_shape = {1};
        std::vector<Ort::Value> inputs;
        inputs.reserve(codec_stream_io_.input_names.size());
        for (const std::string& name : codec_stream_io_.input_names) {
            if (name == "audio_codes") {
                inputs.emplace_back(Ort::Value::CreateTensor<int32_t>(
                    memory,
                    const_cast<int32_t*>(frames.data()),
                    frames.size(),
                    codes_shape.data(),
                    codes_shape.size()
                ));
            } else if (name == "audio_code_lengths") {
                inputs.emplace_back(Ort::Value::CreateTensor<int32_t>(
                    memory,
                    lengths.data(),
                    lengths.size(),
                    length_shape.data(),
                    length_shape.size()
                ));
            } else {
                auto value = state.values.find(name);
                if (value == state.values.end() || !value->second) {
                    error = "MOSS streaming codec is missing input state: " + name;
                    return false;
                }
                inputs.emplace_back(std::move(value->second));
            }
        }

        const auto decode_start = benchmark_enabled_
            ? std::chrono::steady_clock::now()
            : std::chrono::steady_clock::time_point{};
        auto outputs = codec_stream_session_->Run(
            Ort::RunOptions{nullptr},
            codec_stream_io_.input_ptrs.data(),
            inputs.data(),
            inputs.size(),
            codec_stream_io_.output_ptrs.data(),
            codec_stream_io_.output_ptrs.size()
        );
        if (benchmark_enabled_) {
            const auto decode_end = std::chrono::steady_clock::now();
            benchmark_stats_.codec_decode_ms +=
                std::chrono::duration<double, std::milli>(
                    decode_end - decode_start
                ).count();
            benchmark_stats_.codec_decode_calls += 1;
        }
        inputs.clear();
        auto output_index = [this](const std::string& name) {
            const auto found = std::find(
                codec_stream_io_.output_names.begin(),
                codec_stream_io_.output_names.end(),
                name
            );
            return found == codec_stream_io_.output_names.end()
                ? codec_stream_io_.output_names.size()
                : static_cast<size_t>(found - codec_stream_io_.output_names.begin());
        };
        const size_t audio_index = output_index("audio");
        const size_t length_index = output_index("audio_lengths");
        if (audio_index >= outputs.size() || length_index >= outputs.size()) {
            error = "MOSS streaming codec output signature is missing audio data.";
            return false;
        }

        int64_t valid_samples = 0;
        const auto length_type = outputs[length_index]
            .GetTensorTypeAndShapeInfo()
            .GetElementType();
        if (length_type == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32) {
            valid_samples = outputs[length_index].GetTensorData<int32_t>()[0];
        } else if (length_type == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64) {
            valid_samples = outputs[length_index].GetTensorData<int64_t>()[0];
        } else {
            error = "MOSS streaming codec returned a non-integer audio length.";
            return false;
        }

        const std::vector<int64_t> audio_shape = tensor_shape(outputs[audio_index]);
        if (audio_shape.size() != 3 || audio_shape[0] != 1 ||
            audio_shape[1] <= 0 || audio_shape[2] <= 0) {
            error = "MOSS streaming codec returned an unexpected audio shape.";
            return false;
        }
        const int64_t channels = audio_shape[1];
        const int64_t available_samples = audio_shape[2];
        valid_samples = (std::max)(int64_t{0}, (std::min)(valid_samples, available_samples));
        const float* audio = outputs[audio_index].GetTensorData<float>();
        out_audio.assign(static_cast<size_t>(valid_samples), 0.0f);
        for (int64_t channel = 0; channel < channels; ++channel) {
            const float* source = audio + channel * available_samples;
            for (int64_t sample = 0; sample < valid_samples; ++sample) {
                out_audio[static_cast<size_t>(sample)] +=
                    source[sample] / static_cast<float>(channels);
            }
        }

        state.values.clear();
        for (const auto& spec : codec_stream_spec_.state_tensors) {
            const size_t index = output_index(spec.output_name);
            if (index >= outputs.size()) {
                error = "MOSS streaming codec is missing output state: " +
                    spec.output_name;
                return false;
            }
            state.values.emplace(spec.input_name, std::move(outputs[index]));
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("MOSS streaming codec decode failed: ") + e.what();
        return false;
    }
}
