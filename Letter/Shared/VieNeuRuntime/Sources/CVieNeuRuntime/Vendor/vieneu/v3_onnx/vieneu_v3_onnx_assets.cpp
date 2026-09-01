#include "../vieneu_v3_onnx.h"
#include "vieneu_v3_onnx_internal.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>
#include <nlohmann/json.hpp>

// --- Helper transposes ---

std::vector<float> transpose_2d(const std::vector<float>& src, int64_t rows, int64_t cols) {
    std::vector<float> dst(static_cast<size_t>(rows * cols));
    for (int64_t r = 0; r < rows; ++r) {
        const float* row = src.data() + r * cols;
        for (int64_t c = 0; c < cols; ++c) {
            dst[static_cast<size_t>(c * rows + r)] = row[c];
        }
    }
    return dst;
}

std::vector<float> transpose_audio_emb(const std::vector<float>& src, int64_t channels, int64_t vocab, int64_t hidden) {
    std::vector<float> dst(static_cast<size_t>(channels * hidden * vocab));
    for (int64_t ch = 0; ch < channels; ++ch) {
        for (int64_t v = 0; v < vocab; ++v) {
            const float* emb = src.data() + (ch * vocab + v) * hidden;
            for (int64_t h = 0; h < hidden; ++h) {
                dst[static_cast<size_t>((ch * hidden + h) * vocab + v)] = emb[h];
            }
        }
    }
    return dst;
}

// --- NPZ / NPY Loader Helpers ---

std::vector<std::string> parse_shape_items(const std::string& shape_text) {
    std::vector<std::string> out;
    std::string cur;
    for (char c : shape_text) {
        if (c == ',') {
            if (!cur.empty()) {
                out.push_back(cur);
                cur.clear();
            }
        } else if (!std::isspace(static_cast<unsigned char>(c)) && c != '(' && c != ')') {
            cur.push_back(c);
        }
    }
    if (!cur.empty()) {
        out.push_back(cur);
    }
    return out;
}

NamedArray parse_npy(const uint8_t* data, size_t size, const std::string& name) {
    if (size < 16 || std::memcmp(data, "\x93NUMPY", 6) != 0) {
        throw std::runtime_error("invalid npy header for " + name);
    }
    const uint8_t major = data[6];
    size_t header_len = 0;
    size_t header_offset = 0;
    if (major == 1) {
        header_len = read_u16_le(data + 8);
        header_offset = 10;
    } else if (major == 2 || major == 3) {
        header_len = read_u32_le(data + 8);
        header_offset = 12;
    } else {
        throw std::runtime_error("unsupported npy version for " + name);
    }
    if (header_offset + header_len > size) {
        throw std::runtime_error("truncated npy header for " + name);
    }
    const std::string header(reinterpret_cast<const char*>(data + header_offset), header_len);
    const bool is_f16 = header.find("'descr': '<f2'") != std::string::npos || header.find("\"descr\": \"<f2\"") != std::string::npos;
    const bool is_f32 = header.find("'descr': '<f4'") != std::string::npos || header.find("\"descr\": \"<f4\"") != std::string::npos;
    if (!is_f16 && !is_f32) {
        throw std::runtime_error("unsupported npy dtype for " + name + " (expected float16 or float32)");
    }
    if (header.find("True") != std::string::npos) {
        throw std::runtime_error("fortran-order npy arrays are not supported for " + name);
    }
    const size_t shape_pos = header.find("'shape':");
    const size_t paren_start = header.find('(', shape_pos);
    const size_t paren_end = header.find(')', paren_start);
    if (shape_pos == std::string::npos || paren_start == std::string::npos || paren_end == std::string::npos) {
        throw std::runtime_error("missing npy shape for " + name);
    }

    NamedArray arr;
    const auto items = parse_shape_items(header.substr(paren_start, paren_end - paren_start + 1));
    int64_t count = 1;
    for (const std::string& item : items) {
        const int64_t dim = std::stoll(item);
        arr.shape.push_back(dim);
        count *= dim;
    }

    const size_t payload_offset = header_offset + header_len;
    const size_t element_bytes = is_f16 ? sizeof(uint16_t) : sizeof(float);
    const size_t payload_bytes = static_cast<size_t>(count) * element_bytes;
    if (payload_offset + payload_bytes > size) {
        throw std::runtime_error("truncated npy payload for " + name);
    }
    arr.data.resize(static_cast<size_t>(count));
    const uint8_t* p = data + payload_offset;
    if (is_f16) {
        for (int64_t i = 0; i < count; ++i) {
            arr.data[static_cast<size_t>(i)] = half_to_float(read_u16_le(p + i * 2));
        }
    } else {
        for (int64_t i = 0; i < count; ++i) {
            float v = 0.0f;
            std::memcpy(&v, p + static_cast<size_t>(i) * sizeof(float), sizeof(float));
            arr.data[static_cast<size_t>(i)] = v;
        }
    }
    return arr;
}

std::unordered_map<std::string, NamedArray> load_npz_stored(const std::string& path) {
    const std::string bytes = read_file_bytes(path);
    const auto* data = reinterpret_cast<const uint8_t*>(bytes.data());
    const size_t size = bytes.size();
    size_t off = 0;
    std::unordered_map<std::string, NamedArray> arrays;

    while (off + 30 <= size) {
        const uint32_t sig = read_u32_le(data + off);
        if (sig != 0x04034b50u) {
            break;
        }
        const uint16_t method = read_u16_le(data + off + 8);
        const uint32_t compressed_size32 = read_u32_le(data + off + 18);
        const uint32_t uncompressed_size32 = read_u32_le(data + off + 22);
        const uint16_t name_len = read_u16_le(data + off + 26);
        const uint16_t extra_len = read_u16_le(data + off + 28);
        const size_t name_off = off + 30;
        const size_t payload_off = name_off + name_len + extra_len;
        uint64_t compressed_size64 = compressed_size32;
        uint64_t uncompressed_size64 = uncompressed_size32;
        if (compressed_size32 == 0xFFFFFFFFu || uncompressed_size32 == 0xFFFFFFFFu) {
            bool found_zip64 = false;
            size_t extra_off = name_off + name_len;
            const size_t extra_end = extra_off + extra_len;
            while (extra_off + 4 <= extra_end) {
                const uint16_t field_id = read_u16_le(data + extra_off);
                const uint16_t field_size = read_u16_le(data + extra_off + 2);
                const size_t field_payload = extra_off + 4;
                if (field_payload + field_size > extra_end) {
                    throw std::runtime_error("truncated zip extra field in " + path);
                }
                if (field_id == 0x0001u) {
                    found_zip64 = true;
                    size_t zip64_off = field_payload;
                    if (uncompressed_size32 == 0xFFFFFFFFu) {
                        if (zip64_off + 8 > field_payload + field_size) {
                            throw std::runtime_error("truncated zip64 uncompressed size in " + path);
                        }
                        uncompressed_size64 = read_u64_le(data + zip64_off);
                        zip64_off += 8;
                    }
                    if (compressed_size32 == 0xFFFFFFFFu) {
                        if (zip64_off + 8 > field_payload + field_size) {
                            throw std::runtime_error("truncated zip64 compressed size in " + path);
                        }
                        compressed_size64 = read_u64_le(data + zip64_off);
                    }
                    break;
                }
                extra_off = field_payload + field_size;
            }
            if (!found_zip64) {
                throw std::runtime_error("missing zip64 size extra field in " + path);
            }
        }
        if (compressed_size64 > static_cast<uint64_t>(std::numeric_limits<size_t>::max()) ||
            uncompressed_size64 > static_cast<uint64_t>(std::numeric_limits<size_t>::max())) {
            throw std::runtime_error("npz entry is too large in " + path);
        }
        const size_t compressed_size = static_cast<size_t>(compressed_size64);
        const size_t uncompressed_size = static_cast<size_t>(uncompressed_size64);
        if (payload_off > size || payload_off + compressed_size > size) {
            throw std::runtime_error("truncated npz entry in " + path);
        }
        std::string name(reinterpret_cast<const char*>(data + name_off), name_len);
        if (method != 0) {
            throw std::runtime_error("compressed npz entries are not supported: " + name);
        }
        if (compressed_size != uncompressed_size) {
            throw std::runtime_error("invalid stored npz size for " + name);
        }
        arrays[name] = parse_npy(data + payload_off, uncompressed_size, name);
        off = payload_off + compressed_size;
    }
    return arrays;
}

// --- VieneuV3OnnxEngine Member Functions ---

bool VieneuV3OnnxEngine::load_session(const std::string& path, std::unique_ptr<Ort::Session>& session, std::string& error) {
    try {
#ifdef _WIN32
        std::wstring w_path(path.begin(), path.end());
        session = std::make_unique<Ort::Session>(
            *env_, w_path.c_str(), *session_options_, *prepacked_weights_);
#else
        session = std::make_unique<Ort::Session>(
            *env_, path.c_str(), *session_options_, *prepacked_weights_);
#endif
        return true;
    } catch (const std::exception& e) {
        error = "Failed to load ONNX session " + path + ": " + e.what();
        return false;
    }
}

void VieneuV3OnnxEngine::cache_session_io(Ort::Session& session, SessionIo& io) {
    io.input_names = session_input_names(session);
    io.output_names = session_output_names(session);
    io.input_ptrs = name_ptrs(io.input_names);
    io.output_ptrs = name_ptrs(io.output_names);
}

bool VieneuV3OnnxEngine::validate_assets(const VieneuV3OnnxInit& init, std::string& error) {
    onnx_dir_ = init.onnx_dir.empty() ? init.model_dir : init.onnx_dir;
    model_dir_ = init.model_dir.empty() ? onnx_dir_ : init.model_dir;
    codec_dir_ = init.codec_dir;
    const std::string config_path = init.config_path.empty() ? join_path(model_dir_, "config.json") : init.config_path;
    const std::string tokenizer_path = init.tokenizer_path.empty() ? join_path(model_dir_, "tokenizer.json") : init.tokenizer_path;

    const std::vector<std::string> required = {
        join_path(onnx_dir_, "vieneu_prefill.onnx"),
        join_path(onnx_dir_, "vieneu_decode_step.onnx"),
        join_path(onnx_dir_, "vieneu_acoustic_cached.onnx"),
        join_path(onnx_dir_, "vieneu_v3_heads.npz"),
        config_path,
        tokenizer_path,
        join_path(codec_dir_, "moss_audio_tokenizer_decode_full.onnx"),
        join_path(codec_dir_, "moss_audio_tokenizer_decode_step.onnx"),
        join_path(codec_dir_, "codec_browser_onnx_meta.json"),
    };

    for (const std::string& path : required) {
        if (!file_exists(path)) {
            error = "Missing required VieNeu v3 ONNX asset: " + path;
            return false;
        }
    }
    codec_decode_path_ = join_path(
        codec_dir_,
        "moss_audio_tokenizer_decode_full.onnx"
    );
    codec_encode_path_.clear();
    return true;
}

bool VieneuV3OnnxEngine::load_codec_stream_spec(
    const std::string& path,
    std::string& error
) {
    codec_stream_spec_ = CodecStreamSpec{};
    try {
        const auto root = nlohmann::json::parse(read_file_bytes(path));
        const auto& stream = root.at("streaming_decode");
        auto shape = [](const nlohmann::json& value) {
            return value.get<std::vector<int64_t>>();
        };
        auto add_int = [this](
            const std::string& input,
            const std::string& output,
            std::vector<int64_t> dimensions,
            int32_t initial_value = 0
        ) {
            CodecStreamTensorSpec spec;
            spec.input_name = input;
            spec.output_name = output;
            spec.shape = std::move(dimensions);
            spec.data_type = CodecStreamDataType::int32;
            spec.initial_int_value = initial_value;
            codec_stream_spec_.state_tensors.push_back(std::move(spec));
        };
        auto add_float = [this](
            const std::string& input,
            const std::string& output,
            std::vector<int64_t> dimensions
        ) {
            CodecStreamTensorSpec spec;
            spec.input_name = input;
            spec.output_name = output;
            spec.shape = std::move(dimensions);
            spec.data_type = CodecStreamDataType::float32;
            codec_stream_spec_.state_tensors.push_back(std::move(spec));
        };

        for (const auto& item : stream.at("transformer_offsets")) {
            add_int(
                item.at("input_name").get<std::string>(),
                item.at("output_name").get<std::string>(),
                shape(item.at("shape"))
            );
        }
        for (const auto& item : stream.at("attention_caches")) {
            add_int(
                item.at("offset_input_name").get<std::string>(),
                item.at("offset_output_name").get<std::string>(),
                shape(item.at("offset_shape"))
            );
            add_float(
                item.at("cached_keys_input_name").get<std::string>(),
                item.at("cached_keys_output_name").get<std::string>(),
                shape(item.at("cache_shape"))
            );
            add_float(
                item.at("cached_values_input_name").get<std::string>(),
                item.at("cached_values_output_name").get<std::string>(),
                shape(item.at("cache_shape"))
            );
            add_int(
                item.at("cached_positions_input_name").get<std::string>(),
                item.at("cached_positions_output_name").get<std::string>(),
                shape(item.at("positions_shape")),
                -1
            );
        }
        if (codec_stream_spec_.state_tensors.empty()) {
            error = "MOSS codec streaming metadata contains no decoder state.";
            return false;
        }
        codec_stream_spec_.loaded = true;
        return true;
    } catch (const std::exception& e) {
        error = std::string("Failed to load MOSS streaming codec metadata: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::load_config(const std::string& path, std::string& error) {
    try {
        const auto c = nlohmann::json::parse(read_file_bytes(path));
        config_.n_vq = c.value("n_vq", config_.n_vq);
        config_.hidden_size = c.value("hidden_size", config_.hidden_size);
        config_.num_hidden_layers = c.value("num_hidden_layers", config_.num_hidden_layers);
        config_.audio_pad_token_id = c.value("audio_pad_token_id", config_.audio_pad_token_id);
        config_.text_prompt_start_token_id = c.value("text_prompt_start_token_id", config_.text_prompt_start_token_id);
        config_.text_prompt_end_token_id = c.value("text_prompt_end_token_id", config_.text_prompt_end_token_id);
        config_.speech_generation_start_token_id = c.value("speech_generation_start_token_id", config_.speech_generation_start_token_id);
        config_.speech_generation_end_token_id = c.value("speech_generation_end_token_id", config_.speech_generation_end_token_id);
        config_.audio_ref_slot_token_id = c.value("audio_ref_slot_token_id", config_.audio_ref_slot_token_id);
        config_.default_style_token_id = c.value("default_style_token_id", config_.default_style_token_id);
        config_.audio_vocab_size = c.value("audio_vocab_size", config_.audio_vocab_size);
        config_.local_num_attention_heads = c.value("local_num_attention_heads", config_.local_num_attention_heads);
        config_.local_num_hidden_layers = c.value("local_num_hidden_layers", config_.local_num_hidden_layers);
        config_.use_speaker_embedding = c.value("use_speaker_embedding", config_.use_speaker_embedding);
        config_.speaker_embedding_dim = c.value("speaker_embedding_dim", config_.speaker_embedding_dim);
        if (c.contains("style_labels") && c.at("style_labels").is_object()) {
            config_.style_labels.clear();
            for (auto it = c.at("style_labels").begin(); it != c.at("style_labels").end(); ++it) {
                config_.style_labels[it.key()] = it.value().get<int>();
            }
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("Failed to load VieNeu v3 config: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::load_heads_npz(const std::string& path, std::string& error) {
    try {
        auto arrays = load_npz_stored(path);
        auto find_array = [&arrays](const std::string& name) -> NamedArray* {
            auto it = arrays.find(name + ".npy");
            if (it == arrays.end()) {
                it = arrays.find(name);
            }
            return it == arrays.end() ? nullptr : &it->second;
        };
        NamedArray* text = find_array("text_emb");
        NamedArray* audio = find_array("audio_emb");
        if (!text || !audio) {
            error = "vieneu_v3_heads.npz is missing text_emb.npy or audio_emb.npy";
            return false;
        }
        if (text->shape.size() != 2 || audio->shape.size() != 3) {
            error = "Unexpected embedding rank in vieneu_v3_heads.npz";
            return false;
        }
        text_emb_.rows = text->shape[0];
        text_emb_.cols = text->shape[1];
        text_emb_.data = std::move(text->data);
        text_emb_t_.rows = text_emb_.cols;
        text_emb_t_.cols = text_emb_.rows;
        text_emb_t_.data = transpose_2d(text_emb_.data, text_emb_.rows, text_emb_.cols);
        audio_emb_.dim0 = audio->shape[0];
        audio_emb_.dim1 = audio->shape[1];
        audio_emb_.dim2 = audio->shape[2];
        audio_emb_.data = std::move(audio->data);
        audio_emb_t_.dim0 = audio_emb_.dim0;
        audio_emb_t_.dim1 = audio_emb_.dim2;
        audio_emb_t_.dim2 = audio_emb_.dim1;
        audio_emb_t_.data = transpose_audio_emb(audio_emb_.data, audio_emb_.dim0, audio_emb_.dim1, audio_emb_.dim2);
        if (text_emb_.cols != config_.hidden_size || audio_emb_.dim2 != config_.hidden_size) {
            error = "Embedding hidden size does not match config.json";
            return false;
        }

        speaker_projection_weights_.clear();
        speaker_projection_bias_.clear();
        speaker_layer_norm_weights_.clear();
        speaker_layer_norm_bias_.clear();
        speaker_layer_norm_epsilon_ = 1.0e-5f;
        if (NamedArray* value = find_array("xvec_w")) {
            speaker_projection_weights_ = std::move(value->data);
        }
        if (NamedArray* value = find_array("xvec_b")) {
            speaker_projection_bias_ = std::move(value->data);
        }
        if (NamedArray* value = find_array("xvec_ln_w")) {
            speaker_layer_norm_weights_ = std::move(value->data);
        }
        if (NamedArray* value = find_array("xvec_ln_b")) {
            speaker_layer_norm_bias_ = std::move(value->data);
        }
        if (const NamedArray* value = find_array("xvec_ln_eps"); value && !value->data.empty()) {
            speaker_layer_norm_epsilon_ = value->data[0];
        }
        if (config_.use_speaker_embedding) {
            const size_t hidden_size = static_cast<size_t>(config_.hidden_size);
            const size_t expected_projection_size = hidden_size *
                static_cast<size_t>(config_.speaker_embedding_dim);
            if (speaker_projection_weights_.size() != expected_projection_size ||
                speaker_projection_bias_.size() != hidden_size ||
                speaker_layer_norm_weights_.size() != hidden_size ||
                speaker_layer_norm_bias_.size() != hidden_size) {
                error = "vieneu_v3_heads.npz is missing valid speaker projection tensors.";
                return false;
            }
        }
        return true;
    } catch (const std::exception& e) {
        error = std::string("Failed to load vieneu_v3_heads.npz: ") + e.what();
        return false;
    }
}

bool VieneuV3OnnxEngine::compute_speaker_anchor(
    const std::vector<float>& speaker_embedding,
    std::vector<float>& anchor,
    std::string& error) const {
    anchor.clear();
    if (!config_.use_speaker_embedding) {
        return true;
    }
    if (speaker_embedding.size() != static_cast<size_t>(config_.speaker_embedding_dim)) {
        error = "VieNeu v3 speaker embedding dimension does not match config.json.";
        return false;
    }

    const int hidden_size = config_.hidden_size;
    const int speaker_size = config_.speaker_embedding_dim;
    anchor.assign(static_cast<size_t>(hidden_size), 0.0f);
    for (int hidden = 0; hidden < hidden_size; ++hidden) {
        double value = speaker_projection_bias_[static_cast<size_t>(hidden)];
        const float* weights = speaker_projection_weights_.data() +
            static_cast<size_t>(hidden * speaker_size);
        for (int speaker = 0; speaker < speaker_size; ++speaker) {
            value += static_cast<double>(weights[speaker]) *
                speaker_embedding[static_cast<size_t>(speaker)];
        }
        anchor[static_cast<size_t>(hidden)] = static_cast<float>(value);
    }

    double mean = 0.0;
    for (float value : anchor) {
        mean += value;
    }
    mean /= static_cast<double>(hidden_size);
    double variance = 0.0;
    for (float value : anchor) {
        const double difference = static_cast<double>(value) - mean;
        variance += difference * difference;
    }
    variance /= static_cast<double>(hidden_size);
    const double inverseStandardDeviation = 1.0 /
        std::sqrt(variance + static_cast<double>(speaker_layer_norm_epsilon_));
    for (int hidden = 0; hidden < hidden_size; ++hidden) {
        const double normalized =
            (static_cast<double>(anchor[static_cast<size_t>(hidden)]) - mean) *
            inverseStandardDeviation;
        anchor[static_cast<size_t>(hidden)] = static_cast<float>(
            normalized * speaker_layer_norm_weights_[static_cast<size_t>(hidden)] +
            speaker_layer_norm_bias_[static_cast<size_t>(hidden)]
        );
    }
    return true;
}
