#include "../vieneu_v3_onnx.h"
#include "vieneu_v3_onnx_internal.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <string>
#include <vector>
#include <stdexcept>

// --- VieneuV3OnnxEngine Inference Member Functions ---

namespace {

std::string acoustic_backend_from_env() {
    const char* value = std::getenv("VIENEU_ACOUSTIC_BACKEND");
    std::string backend = value ? std::string(value) : std::string("onnx");
    std::transform(backend.begin(), backend.end(), backend.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return backend;
}

} // namespace

class VieneuV3OnnxEngine::OnnxAcousticExecutor final : public VieneuV3OnnxEngine::AcousticExecutor {
public:
    explicit OnnxAcousticExecutor(VieneuV3OnnxEngine& engine) : engine_(engine) {}

    bool generate_frame(const std::vector<float>& h,
                        float temperature,
                        int top_k,
                        float top_p,
                        float repetition_penalty,
                        std::vector<V3RepetitionHistory>& history,
                        std::vector<int64_t>& codes,
                        bool& eos,
                        std::string& error) override {
        return engine_.acoustic_frame_onnx(
            h,
            temperature,
            top_k,
            top_p,
            repetition_penalty,
            history,
            codes,
            eos,
            error);
    }

private:
    VieneuV3OnnxEngine& engine_;
};

bool VieneuV3OnnxEngine::initialize_acoustic_executor(std::string& error) {
    const std::string backend = acoustic_backend_from_env();
    if (backend != "onnx") {
        error = "The Letter iOS runtime supports only the ONNX acoustic backend.";
        return false;
    }
    if (!acoustic_session_) {
        error = "VieNeu v3 acoustic ONNX session is not initialized.";
        return false;
    }
    acoustic_executor_ = std::make_unique<OnnxAcousticExecutor>(*this);
    return true;
}

VieneuV3OnnxEngine::PromptRows VieneuV3OnnxEngine::build_rows(
    const std::string& phonemes,
    const std::vector<int64_t>* ref_codes,
    int leading_token) const {
    const std::vector<int64_t> phone_ids = tokenizer_.encode(phonemes);
    const int64_t cols = config_.n_vq + 1;
    const int64_t text_rows = static_cast<int64_t>(phone_ids.size()) + 3;
    const int64_t ref_rows = ref_codes ? static_cast<int64_t>(ref_codes->size() / config_.n_vq) : 0;
    PromptRows rows;
    rows.rows = text_rows + ref_rows;
    rows.cols = cols;
    rows.data.assign(static_cast<size_t>(rows.rows * rows.cols), config_.audio_pad_token_id);
    rows.data[0] = leading_token;
    rows.data[cols] = config_.text_prompt_start_token_id;
    for (size_t i = 0; i < phone_ids.size(); ++i) {
        rows.data[static_cast<size_t>((static_cast<int64_t>(i) + 2) * cols)] = phone_ids[i];
    }
    rows.data[static_cast<size_t>((text_rows - 1) * cols)] = config_.text_prompt_end_token_id;
    if (ref_codes) {
        for (int64_t r = 0; r < ref_rows; ++r) {
            const int64_t dst_row = text_rows + r;
            rows.data[static_cast<size_t>(dst_row * cols)] = config_.audio_ref_slot_token_id;
            for (int ch = 0; ch < config_.n_vq; ++ch) {
                rows.data[static_cast<size_t>(dst_row * cols + ch + 1)] =
                    (*ref_codes)[static_cast<size_t>(r * config_.n_vq + ch)];
            }
        }
    }
    return rows;
}

std::vector<float> VieneuV3OnnxEngine::embed_rows(
    const PromptRows& rows,
    const std::vector<float>* speaker_anchor) const {
    std::vector<float> embeds(static_cast<size_t>(rows.rows * config_.hidden_size), 0.0f);
    for (int64_t r = 0; r < rows.rows; ++r) {
        float* dst = embeds.data() + r * config_.hidden_size;
        const int64_t text_id = rows.data[static_cast<size_t>(r * rows.cols)];
        if (text_id >= 0 && text_id < text_emb_.rows) {
            const float* src = text_emb_.data.data() + text_id * text_emb_.cols;
            std::copy(src, src + config_.hidden_size, dst);
        }
        for (int ch = 0; ch < config_.n_vq; ++ch) {
            const int64_t id = rows.data[static_cast<size_t>(r * rows.cols + ch + 1)];
            if (id == config_.audio_pad_token_id || id < 0 || id >= audio_emb_.dim1) {
                continue;
            }
            const float* src = audio_emb_.data.data() +
                (static_cast<int64_t>(ch) * audio_emb_.dim1 + id) * audio_emb_.dim2;
            for (int h = 0; h < config_.hidden_size; ++h) {
                dst[h] += src[h];
            }
        }
        if (speaker_anchor && speaker_anchor->size() == static_cast<size_t>(config_.hidden_size)) {
            for (int h = 0; h < config_.hidden_size; ++h) {
                dst[h] += (*speaker_anchor)[static_cast<size_t>(h)];
            }
        }
    }
    return embeds;
}

bool VieneuV3OnnxEngine::acoustic_frame(
    const std::vector<float>& h,
    float temperature,
    int top_k,
    float top_p,
    float repetition_penalty,
    std::vector<V3RepetitionHistory>& history,
    std::vector<int64_t>& codes,
    bool& eos,
    std::string& error) {
    if (!acoustic_executor_) {
        error = "VieNeu v3 acoustic executor is not initialized.";
        return false;
    }
    return acoustic_executor_->generate_frame(
        h,
        temperature,
        top_k,
        top_p,
        repetition_penalty,
        history,
        codes,
        eos,
        error);
}

bool VieneuV3OnnxEngine::acoustic_frame_onnx(
    const std::vector<float>& h,
    float temperature,
    int top_k,
    float top_p,
    float repetition_penalty,
    std::vector<V3RepetitionHistory>& history,
    std::vector<int64_t>& codes,
    bool& eos,
    std::string& error) {
    const auto frame_start = benchmark_enabled_ ? std::chrono::steady_clock::now() : std::chrono::steady_clock::time_point{};
    try {
        const int H = config_.hidden_size;
        const int nH = config_.local_num_attention_heads;
        const int hd = H / nH;
        acoustic_token_.resize(static_cast<size_t>(2 * H));
        std::copy(h.begin(), h.begin() + H, acoustic_token_.begin());
        const float* sgs = text_emb_.data.data() + config_.speech_generation_start_token_id * text_emb_.cols;
        std::copy(sgs, sgs + H, acoustic_token_.begin() + H);
        std::array<int64_t, 2> pos = {0, 1};
        acoustic_empty_.clear();
        std::array<int64_t, 4> empty_shape = {1, nH, 0, hd};
        std::array<int64_t, 3> token_shape = {1, 2, H};
        std::array<int64_t, 2> pos_shape = {1, 2};

        Ort::MemoryInfo& mem = cpu_memory_info();
        const size_t local_layers = static_cast<size_t>(config_.local_num_hidden_layers);
        const size_t expected_inputs = 2 + local_layers * 2;
        const size_t expected_outputs = 1 + local_layers * 2;
        if (acoustic_io_.input_names.size() != expected_inputs ||
            acoustic_io_.output_names.size() != expected_outputs) {
            error = "VieNeu v3 acoustic ONNX signature does not match local_num_hidden_layers.";
            return false;
        }
        acoustic_inputs_.clear();
        acoustic_inputs_.reserve(expected_inputs);
        acoustic_inputs_.emplace_back(Ort::Value::CreateTensor<float>(
            mem, acoustic_token_.data(), acoustic_token_.size(), token_shape.data(), token_shape.size()));
        acoustic_inputs_.emplace_back(Ort::Value::CreateTensor<int64_t>(
            mem, pos.data(), pos.size(), pos_shape.data(), pos_shape.size()));
        for (size_t layer = 0; layer < local_layers * 2; ++layer) {
            acoustic_inputs_.emplace_back(Ort::Value::CreateTensor<float>(
                mem, acoustic_empty_.data(), 0, empty_shape.data(), empty_shape.size()));
        }
        const Ort::RunOptions run_options{nullptr};
        auto out = acoustic_session_->Run(
            run_options,
            acoustic_io_.input_ptrs.data(),
            acoustic_inputs_.data(),
            acoustic_inputs_.size(),
            acoustic_io_.output_ptrs.data(),
            acoustic_io_.output_ptrs.size());
        acoustic_inputs_.clear();
        Ort::Value hidden_val = std::move(out[0]);
        std::vector<Ort::Value> past_keys;
        std::vector<Ort::Value> past_values;
        past_keys.reserve(local_layers);
        past_values.reserve(local_layers);
        for (size_t layer = 0; layer < local_layers; ++layer) {
            past_keys.emplace_back(std::move(out[1 + layer]));
            past_values.emplace_back(std::move(out[1 + local_layers + layer]));
        }

        const float* hidden_ptr = hidden_val.GetTensorData<float>();
        acoustic_slot0_.assign(hidden_ptr, hidden_ptr + H);

        auto sample_channel = [&](int ch, const float* vec) {
            const float* head = audio_emb_t_.data.data() + static_cast<int64_t>(ch) * audio_emb_t_.dim1 * audio_emb_t_.dim2;
            matvec_transposed(vec, head, audio_emb_t_.dim1, audio_emb_t_.dim2, acoustic_logits_);
            V3RepetitionHistory* prev = history.empty() ? nullptr : &history[static_cast<size_t>(ch)];
            int64_t code = sample_logits(acoustic_logits_, temperature, top_k, top_p, repetition_penalty, prev);
            if (prev) prev->add(static_cast<int32_t>(code));
            return code;
        };

        codes.clear();
        codes.reserve(static_cast<size_t>(config_.n_vq));
        codes.push_back(sample_channel(0, hidden_ptr + H));
        for (int ch = 1; ch < config_.n_vq; ++ch) {
            const float* emb = audio_emb_.data.data() +
                (static_cast<int64_t>(ch - 1) * audio_emb_.dim1 + codes.back()) * audio_emb_.dim2;
            int64_t step_pos = ch + 1;
            std::array<int64_t, 3> step_token_shape = {1, 1, H};
            std::array<int64_t, 2> step_pos_shape = {1, 1};
            acoustic_step_inputs_.clear();
            acoustic_step_inputs_.reserve(expected_inputs);
            acoustic_step_inputs_.emplace_back(Ort::Value::CreateTensor<float>(
                mem, const_cast<float*>(emb), static_cast<size_t>(H),
                step_token_shape.data(), step_token_shape.size()));
            acoustic_step_inputs_.emplace_back(Ort::Value::CreateTensor<int64_t>(
                mem, &step_pos, 1, step_pos_shape.data(), step_pos_shape.size()));
            for (auto& past_key : past_keys) {
                acoustic_step_inputs_.emplace_back(std::move(past_key));
            }
            for (auto& past_value : past_values) {
                acoustic_step_inputs_.emplace_back(std::move(past_value));
            }
            auto step_out = acoustic_session_->Run(
                run_options,
                acoustic_io_.input_ptrs.data(),
                acoustic_step_inputs_.data(),
                acoustic_step_inputs_.size(),
                acoustic_io_.output_ptrs.data(),
                acoustic_io_.output_ptrs.size());
            hidden_val = std::move(step_out[0]);
            for (size_t layer = 0; layer < local_layers; ++layer) {
                past_keys[layer] = std::move(step_out[1 + layer]);
                past_values[layer] = std::move(step_out[1 + local_layers + layer]);
            }
            acoustic_step_inputs_.clear();
            
            const float* step_hidden_ptr = hidden_val.GetTensorData<float>();
            codes.push_back(sample_channel(ch, step_hidden_ptr));
        }

        matvec_transposed(acoustic_slot0_.data(), text_emb_t_.data.data(), text_emb_t_.rows, text_emb_t_.cols, acoustic_text_logits_);
        eos = static_cast<int>(std::distance(acoustic_text_logits_.begin(), std::max_element(acoustic_text_logits_.begin(), acoustic_text_logits_.end()))) ==
              config_.speech_generation_end_token_id;
        if (benchmark_enabled_) {
            const auto frame_end = std::chrono::steady_clock::now();
            benchmark_stats_.acoustic_frame_ms += std::chrono::duration<double, std::milli>(frame_end - frame_start).count();
            benchmark_stats_.acoustic_frame_calls += 1;
        }
        return true;
    } catch (const std::exception& e) {
        if (benchmark_enabled_) {
            const auto frame_end = std::chrono::steady_clock::now();
            benchmark_stats_.acoustic_frame_ms += std::chrono::duration<double, std::milli>(frame_end - frame_start).count();
            benchmark_stats_.acoustic_frame_calls += 1;
        }
        error = std::string("VieNeu v3 acoustic frame failed: ") + e.what();
        return false;
    }
}
