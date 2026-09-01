#include "VieNeuRuntime.h"
#include "Vendor/vieneu/vieneu.h"
#include "Vendor/vieneu/vieneu_v3_onnx.h"

#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <new>
#include <string>
#include <vector>

struct letter_vieneu_engine {
    VieneuV3OnnxEngine runtime;
    std::string error;
    bool ready = false;
};

struct letter_vieneu_cancellation {
    std::atomic_bool requested{false};
};

namespace {

std::string string_or_empty(const char *value) {
    return value ? value : "";
}

void clear_audio(letter_vieneu_audio *audio) {
    if (!audio) {
        return;
    }
    audio->samples = nullptr;
    audio->sample_count = 0;
    audio->sample_rate = 0;
}

VieneuV3OnnxParams make_params(
    const letter_vieneu_synthesis_options& options,
    const letter_vieneu_cancellation *cancellation
) {
    VieneuV3OnnxParams params;
    params.text = options.text;
    params.voice_id = string_or_empty(options.voice_id);
    params.temperature = options.temperature;
    params.top_k = options.top_k;
    params.top_p = options.top_p;
    params.max_new_frames = options.maximum_frames;
    params.repetition_penalty = options.repetition_penalty;
    params.max_chars = options.maximum_characters;
    params.playback_rate = (std::max)(0.5f, (std::min)(options.playback_rate, 3.0f));
    params.apply_watermark = false;
    params.cancelled = [cancellation]() {
        return letter_vieneu_cancellation_is_requested(cancellation) == 1;
    };
    return params;
}

}  // namespace

letter_vieneu_configuration letter_vieneu_default_configuration(void) {
    letter_vieneu_configuration configuration{};
    configuration.thread_count = 0;
    return configuration;
}

letter_vieneu_synthesis_options letter_vieneu_default_synthesis_options(void) {
    letter_vieneu_synthesis_options options{};
    options.temperature = 0.8f;
    options.top_k = 25;
    options.top_p = 0.95f;
    options.maximum_frames = 300;
    options.repetition_penalty = 1.2f;
    options.maximum_characters = 384;
    options.playback_rate = 1.0f;
    return options;
}

letter_vieneu_engine *letter_vieneu_create(
    const letter_vieneu_configuration *configuration
) {
    if (!configuration) {
        return nullptr;
    }

    auto engine = std::make_unique<letter_vieneu_engine>();
    VieneuV3OnnxInit init;
    init.model_dir = string_or_empty(configuration->model_directory);
    init.onnx_dir = string_or_empty(configuration->onnx_directory);
    init.codec_dir = string_or_empty(configuration->codec_directory);
    init.voices_json_path = string_or_empty(configuration->voices_json_path);
    init.n_threads = configuration->thread_count;
    VieneuProfile::configure_phonemizer_dictionary(
        string_or_empty(configuration->g2p_dictionary_path)
    );

    engine->ready = engine->runtime.initialize(init, engine->error);
    return engine.release();
}

void letter_vieneu_destroy(letter_vieneu_engine *engine) {
    delete engine;
}

int32_t letter_vieneu_is_ready(const letter_vieneu_engine *engine) {
    return engine && engine->ready ? 1 : 0;
}

letter_vieneu_cancellation *letter_vieneu_cancellation_create(void) {
    return new (std::nothrow) letter_vieneu_cancellation();
}

void letter_vieneu_cancellation_request(
    letter_vieneu_cancellation *cancellation
) {
    if (cancellation) {
        cancellation->requested.store(true, std::memory_order_relaxed);
    }
}

int32_t letter_vieneu_cancellation_is_requested(
    const letter_vieneu_cancellation *cancellation
) {
    return cancellation &&
        cancellation->requested.load(std::memory_order_relaxed) ? 1 : 0;
}

void letter_vieneu_cancellation_destroy(
    letter_vieneu_cancellation *cancellation
) {
    delete cancellation;
}

int32_t letter_vieneu_synthesize(
    letter_vieneu_engine *engine,
    const letter_vieneu_synthesis_options *options,
    const letter_vieneu_cancellation *cancellation,
    letter_vieneu_audio *audio
) {
    clear_audio(audio);
    if (!engine || !options || !options->text || !audio) {
        return -1;
    }
    if (!engine->ready) {
        return -5;
    }
    if (letter_vieneu_cancellation_is_requested(cancellation)) {
        engine->error = "VieNeu synthesis cancelled.";
        return -6;
    }

    VieneuV3OnnxParams params = make_params(*options, cancellation);

    std::vector<float> samples;
    engine->error.clear();
    if (!engine->runtime.synthesize(params, samples, engine->error)) {
        if (letter_vieneu_cancellation_is_requested(cancellation)) {
            return -6;
        }
        return -2;
    }
    if (letter_vieneu_cancellation_is_requested(cancellation)) {
        engine->error = "VieNeu synthesis cancelled.";
        return -6;
    }
    if (samples.empty()) {
        engine->error = "VieNeu returned empty audio.";
        return -3;
    }

    const size_t byte_count = samples.size() * sizeof(float);
    auto *buffer = static_cast<float *>(std::malloc(byte_count));
    if (!buffer) {
        engine->error = "Unable to allocate VieNeu output audio.";
        return -4;
    }
    std::memcpy(buffer, samples.data(), byte_count);
    audio->samples = buffer;
    audio->sample_count = samples.size();
    audio->sample_rate = engine->runtime.sample_rate();
    return 0;
}

int32_t letter_vieneu_synthesize_stream(
    letter_vieneu_engine *engine,
    const letter_vieneu_synthesis_options *options,
    const letter_vieneu_cancellation *cancellation,
    letter_vieneu_audio_chunk_callback callback,
    void *context
) {
    if (!engine || !options || !options->text || !callback) {
        return -1;
    }
    if (!engine->ready) {
        return -5;
    }
    if (letter_vieneu_cancellation_is_requested(cancellation)) {
        engine->error = "VieNeu synthesis cancelled.";
        return -6;
    }

    VieneuV3OnnxParams params = make_params(*options, cancellation);
    params.audio_chunk = [callback, context, engine](const std::vector<float>& samples) {
        return callback(
            samples.data(),
            samples.size(),
            engine->runtime.sample_rate(),
            context
        ) == 0;
    };
    std::vector<float> unused_audio;
    engine->error.clear();
    if (!engine->runtime.synthesize(params, unused_audio, engine->error)) {
        return letter_vieneu_cancellation_is_requested(cancellation) ? -6 : -2;
    }
    return 0;
}

void letter_vieneu_audio_free(letter_vieneu_audio *audio) {
    if (!audio) {
        return;
    }
    std::free(audio->samples);
    clear_audio(audio);
}

const char *letter_vieneu_last_error(const letter_vieneu_engine *engine) {
    return engine ? engine->error.c_str() : "VieNeu engine is unavailable.";
}
