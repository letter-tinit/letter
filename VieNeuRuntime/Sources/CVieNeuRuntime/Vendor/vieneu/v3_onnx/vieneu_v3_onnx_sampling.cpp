#include "../vieneu_v3_onnx.h"
#include "vieneu_v3_onnx_internal.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <random>
#include <vector>
#include "../v3_common/v3_repetition_history.h"

#if defined(__APPLE__)
#include <Accelerate/Accelerate.h>
#endif

#if defined(__aarch64__)
#include <arm_neon.h>
#endif

#if defined(__APPLE__) && defined(__aarch64__)
#include <arm/cpu_capabilities_public.h>
#include <sys/sysctl.h>
#endif

// --- Math Kernels ---

namespace {

int32_t dot_product_int8_neon(const int8_t* lhs,
                              const int8_t* rhs,
                              int64_t count) {
    int64_t index = 0;
    int32_t total = 0;
#if defined(__aarch64__)
    int32x4_t accumulator = vdupq_n_s32(0);
    for (; index + 16 <= count; index += 16) {
        const int8x16_t left = vld1q_s8(lhs + index);
        const int8x16_t right = vld1q_s8(rhs + index);
        accumulator = vpadalq_s16(
            accumulator,
            vmull_s8(vget_low_s8(left), vget_low_s8(right)));
        accumulator = vpadalq_s16(
            accumulator,
            vmull_s8(vget_high_s8(left), vget_high_s8(right)));
    }
    total = vaddvq_s32(accumulator);
#endif
    for (; index < count; ++index) {
        total += static_cast<int32_t>(lhs[index]) *
            static_cast<int32_t>(rhs[index]);
    }
    return total;
}

#if defined(__aarch64__)
__attribute__((target("dotprod")))
int32_t dot_product_int8_dotprod(const int8_t* lhs,
                                 const int8_t* rhs,
                                 int64_t count) {
    int64_t index = 0;
    int32x4_t accumulator = vdupq_n_s32(0);
    for (; index + 16 <= count; index += 16) {
        accumulator = vdotq_s32(
            accumulator,
            vld1q_s8(lhs + index),
            vld1q_s8(rhs + index));
    }
    int32_t total = vaddvq_s32(accumulator);
    for (; index < count; ++index) {
        total += static_cast<int32_t>(lhs[index]) *
            static_cast<int32_t>(rhs[index]);
    }
    return total;
}
#endif

bool supports_int8_dot_product() {
#if defined(__APPLE__) && defined(__aarch64__) && defined(HW_OPTIONAL_ARM_CAPS)
    static const bool supported = []() {
        std::array<uint8_t, (CAP_BIT_NB + 7) / 8> capabilities{};
        size_t size = capabilities.size();
        if (sysctlbyname(
                "hw.optional.arm.caps",
                capabilities.data(),
                &size,
                nullptr,
                0) == 0) {
            const size_t byte_index = CAP_BIT_FEAT_DotProd / 8;
            const uint8_t bit_mask = static_cast<uint8_t>(
                1u << (CAP_BIT_FEAT_DotProd % 8));
            return byte_index < size &&
                (capabilities[byte_index] & bit_mask) != 0;
        }
        int legacy_capability = 0;
        size = sizeof(legacy_capability);
        return sysctlbyname(
                   "hw.optional.arm.FEAT_DotProd",
                   &legacy_capability,
                   &size,
                   nullptr,
                   0) == 0 &&
            legacy_capability != 0;
    }();
    return supported;
#else
    return false;
#endif
}

void collect_top_k_pairs(const std::vector<float>& logits, size_t k, std::vector<std::pair<float, size_t>>& out) {
    out.clear();
    out.reserve(k);
    const auto by_logit_min_heap = [](const std::pair<float, size_t>& a, const std::pair<float, size_t>& b) {
        return a.first > b.first;
    };
    for (size_t i = 0; i < logits.size(); ++i) {
        const float value = logits[i];
        if (out.size() < k) {
            out.push_back({value, i});
            std::push_heap(out.begin(), out.end(), by_logit_min_heap);
            continue;
        }
        if (!out.empty() && value > out.front().first) {
            std::pop_heap(out.begin(), out.end(), by_logit_min_heap);
            out.back() = {value, i};
            std::push_heap(out.begin(), out.end(), by_logit_min_heap);
        }
    }
    std::sort(
        out.begin(),
        out.end(),
        [](const std::pair<float, size_t>& a, const std::pair<float, size_t>& b) {
            return a.first > b.first;
        });
}

} // namespace

void quantize_rows_symmetric(const std::vector<float>& source,
                             int64_t rows,
                             int64_t columns,
                             std::vector<int8_t>& quantized,
                             std::vector<float>& row_scales) {
    quantized.resize(static_cast<size_t>(rows * columns));
    row_scales.resize(static_cast<size_t>(rows));
    for (int64_t row_index = 0; row_index < rows; ++row_index) {
        const float* source_row = source.data() + row_index * columns;
        int8_t* quantized_row = quantized.data() + row_index * columns;
        float max_magnitude = 0.0f;
        for (int64_t column = 0; column < columns; ++column) {
            max_magnitude = (std::max)(max_magnitude, std::fabs(source_row[column]));
        }
        const float scale = max_magnitude > 0.0f
            ? max_magnitude / 127.0f
            : 1.0f;
        const float inverse_scale = 1.0f / scale;
        row_scales[static_cast<size_t>(row_index)] = scale;
        for (int64_t column = 0; column < columns; ++column) {
            const long rounded = std::lround(source_row[column] * inverse_scale);
            quantized_row[column] = static_cast<int8_t>(
                (std::max)(-127L, (std::min)(127L, rounded)));
        }
    }
}

void add_quantized_row(const int8_t* row,
                       float scale,
                       int64_t columns,
                       float* destination) {
    for (int64_t column = 0; column < columns; ++column) {
        destination[column] += static_cast<float>(row[column]) * scale;
    }
}

void copy_quantized_row(const int8_t* row,
                        float scale,
                        int64_t columns,
                        std::vector<float>& destination) {
    destination.resize(static_cast<size_t>(columns));
    for (int64_t column = 0; column < columns; ++column) {
        destination[static_cast<size_t>(column)] =
            static_cast<float>(row[column]) * scale;
    }
}

void matvec_quantized_symmetric(const float* vec,
                                const int8_t* matrix_vh,
                                const float* row_scales,
                                int64_t hidden,
                                int64_t vocab,
                                std::vector<int8_t>& quantized_input,
                                std::vector<float>& scaled_input,
                                std::vector<float>& logits) {
    float max_magnitude = 0.0f;
#if defined(__APPLE__)
    vDSP_maxmgv(vec, 1, &max_magnitude, static_cast<vDSP_Length>(hidden));
#else
    for (int64_t index = 0; index < hidden; ++index) {
        max_magnitude = (std::max)(max_magnitude, std::fabs(vec[index]));
    }
#endif
    const float input_scale = max_magnitude > 0.0f
        ? max_magnitude / 127.0f
        : 1.0f;
    const float inverse_scale = 1.0f / input_scale;
    quantized_input.resize(static_cast<size_t>(hidden));
#if defined(__APPLE__)
    scaled_input.resize(static_cast<size_t>(hidden));
    vDSP_vsmul(
        vec,
        1,
        &inverse_scale,
        scaled_input.data(),
        1,
        static_cast<vDSP_Length>(hidden));
    vDSP_vfixr8(
        scaled_input.data(),
        1,
        reinterpret_cast<char*>(quantized_input.data()),
        1,
        static_cast<vDSP_Length>(hidden));
#else
    (void)scaled_input;
    for (int64_t index = 0; index < hidden; ++index) {
        const long rounded = std::lround(vec[index] * inverse_scale);
        quantized_input[static_cast<size_t>(index)] = static_cast<int8_t>(
            (std::max)(-127L, (std::min)(127L, rounded)));
    }
#endif
    logits.resize(static_cast<size_t>(vocab));
#if defined(__aarch64__)
    if (supports_int8_dot_product()) {
        for (int64_t row = 0; row < vocab; ++row) {
            const int32_t dot = dot_product_int8_dotprod(
                quantized_input.data(),
                matrix_vh + row * hidden,
                hidden);
            logits[static_cast<size_t>(row)] =
                static_cast<float>(dot) * input_scale * row_scales[row];
        }
        return;
    }
#endif
    for (int64_t row = 0; row < vocab; ++row) {
        const int32_t dot = dot_product_int8_neon(
            quantized_input.data(),
            matrix_vh + row * hidden,
            hidden);
        logits[static_cast<size_t>(row)] =
            static_cast<float>(dot) * input_scale * row_scales[row];
    }
}

void matvec_transposed(const float* vec, const float* matrix_hv, int64_t hidden, int64_t vocab, std::vector<float>& logits) {
    const size_t out_size = static_cast<size_t>(vocab);
    if (logits.size() != out_size) {
        logits.resize(out_size);
    }
#if defined(__APPLE__)
    cblas_sgemv(
        CblasRowMajor,
        CblasTrans,
        static_cast<int>(hidden),
        static_cast<int>(vocab),
        1.0f,
        matrix_hv,
        static_cast<int>(vocab),
        vec,
        1,
        0.0f,
        logits.data(),
        1
    );
#else
    std::fill(logits.begin(), logits.end(), 0.0f);
    float* out = logits.data();
    for (int64_t h = 0; h < hidden; ++h) {
        const float scale = vec[h];
        const float* row = matrix_hv + h * vocab;
#if defined(_MSC_VER)
#pragma loop(ivdep)
#elif defined(__GNUC__) || defined(__clang__)
#pragma GCC ivdep
#endif
        for (int64_t v = 0; v < vocab; ++v) {
            out[v] += scale * row[v];
        }
    }
#endif
}

// --- VieneuV3OnnxEngine Sampling Member Function ---

int64_t VieneuV3OnnxEngine::sample_logits(
    std::vector<float>& logits,
    float temperature,
    int top_k,
    float top_p,
    float repetition_penalty,
    const V3RepetitionHistory* previous) {
    if (previous && std::fabs(repetition_penalty - 1.0f) > 1e-6f) {
        for (int32_t idx : previous->indices) {
            if (idx >= 0 && static_cast<size_t>(idx) < logits.size()) {
                logits[static_cast<size_t>(idx)] = logits[static_cast<size_t>(idx)] < 0.0f
                    ? logits[static_cast<size_t>(idx)] * repetition_penalty
                    : logits[static_cast<size_t>(idx)] / repetition_penalty;
            }
        }
    }
    if (!(temperature > 0.0f)) {
        return static_cast<int64_t>(std::distance(logits.begin(), std::max_element(logits.begin(), logits.end())));
    }
    for (float& v : logits) {
        v /= temperature;
    }
    
    const size_t N = logits.size();
    if (top_k > 0 && static_cast<size_t>(top_k) < N) {
        const size_t k = static_cast<size_t>(top_k);
        collect_top_k_pairs(logits, k, sampling_pairs_);

        if (top_p > 0.0f && top_p < 1.0f && !sampling_pairs_.empty()) {
            const float max_v = sampling_pairs_[0].first;
            double sum = 0.0;
            sampling_probs_.resize(sampling_pairs_.size());
            for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
                const double e = std::exp(static_cast<double>(sampling_pairs_[i].first - max_v));
                sampling_probs_[i] = static_cast<float>(e);
                sum += e;
            }
            if (sum > 0.0 && std::isfinite(sum)) {
                float cumulative_before = 0.0f;
                size_t keep = 0;
                for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
                    if (cumulative_before > top_p) {
                        break;
                    }
                    cumulative_before += static_cast<float>(static_cast<double>(sampling_probs_[i]) / sum);
                    ++keep;
                }
                sampling_pairs_.resize((std::max)(size_t{1}, keep));
            }
        }

        if (sampling_pairs_.empty()) {
            return 0;
        }

        const float max_v = sampling_pairs_[0].first;
        double sum = 0.0;
        sampling_probs_.resize(sampling_pairs_.size());
        for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
            const double e = std::exp(static_cast<double>(sampling_pairs_[i].first - max_v));
            sampling_probs_[i] = static_cast<float>(e);
            sum += e;
        }
        if (sum <= 0.0 || !std::isfinite(sum)) {
            const float uniform = 1.0f / static_cast<float>(sampling_pairs_.size());
            std::fill(sampling_probs_.begin(), sampling_probs_.end(), uniform);
        } else {
            for (size_t i = 0; i < sampling_probs_.size(); ++i) {
                sampling_probs_[i] = static_cast<float>(static_cast<double>(sampling_probs_[i]) / sum);
            }
        }

        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        const float target = dist(rng_);
        float cumulative = 0.0f;
        for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
            cumulative += sampling_probs_[i];
            if (target <= cumulative) {
                return static_cast<int64_t>(sampling_pairs_[i].second);
            }
        }
        return static_cast<int64_t>(sampling_pairs_.back().second);
    }
    if (top_p > 0.0f && top_p < 1.0f) {
        sampling_pairs_.clear();
        for (size_t i = 0; i < N; ++i) {
            if (logits[i] > -std::numeric_limits<float>::infinity()) {
                sampling_pairs_.push_back({logits[i], i});
            }
        }
        if (!sampling_pairs_.empty()) {
            std::sort(sampling_pairs_.begin(), sampling_pairs_.end(),
                      [](const std::pair<float, size_t>& a, const std::pair<float, size_t>& b) {
                          return a.first > b.first;
                      });
            float max_v = sampling_pairs_[0].first;
            double sum = 0.0;
            sampling_probs_.resize(sampling_pairs_.size());
            for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
                double e = std::exp(static_cast<double>(sampling_pairs_[i].first - max_v));
                sampling_probs_[i] = static_cast<float>(e);
                sum += e;
            }
            if (sum > 0.0 && std::isfinite(sum)) {
                for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
                    sampling_probs_[i] = static_cast<float>(static_cast<double>(sampling_probs_[i]) / sum);
                }
            } else {
                float uniform = 1.0f / static_cast<float>(sampling_pairs_.size());
                std::fill(sampling_probs_.begin(), sampling_probs_.end(), uniform);
            }
            float cumulative_before = 0.0f;
            for (size_t i = 0; i < sampling_pairs_.size(); ++i) {
                if (cumulative_before > top_p) {
                    logits[sampling_pairs_[i].second] = -std::numeric_limits<float>::infinity();
                }
                cumulative_before += sampling_probs_[i];
            }
        }
    }
    
    float max_v = -std::numeric_limits<float>::infinity();
    for (float v : logits) {
        if (v > max_v) max_v = v;
    }
    double sum = 0.0;
    sampling_probs_.resize(N);
    for (size_t i = 0; i < N; ++i) {
        double e = std::exp(static_cast<double>(logits[i] - max_v));
        sampling_probs_[i] = static_cast<float>(e);
        sum += e;
    }
    if (sum <= 0.0 || !std::isfinite(sum)) {
        float uniform = N == 0 ? 0.0f : 1.0f / static_cast<float>(N);
        std::fill(sampling_probs_.begin(), sampling_probs_.end(), uniform);
    } else {
        for (size_t i = 0; i < N; ++i) {
            sampling_probs_[i] = static_cast<float>(static_cast<double>(sampling_probs_[i]) / sum);
        }
    }
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    const float target = dist(rng_);
    float cumulative = 0.0f;
    for (size_t i = 0; i < N; ++i) {
        cumulative += sampling_probs_[i];
        if (target <= cumulative) {
            return static_cast<int64_t>(i);
        }
    }
    return N == 0 ? 0 : static_cast<int64_t>(N - 1);
}
