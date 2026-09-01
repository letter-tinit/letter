#include "VieNeuRuntime.h"
#include "Vendor/vieneu/vieneu.h"
#include "Vendor/vieneu/vieneu_v3_onnx.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

struct letter_vieneu_engine {
    VieneuV3OnnxEngine runtime;
    std::string error;
    bool ready = false;
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

}  // namespace

letter_vieneu_configuration letter_vieneu_default_configuration(void) {
    letter_vieneu_configuration configuration{};
    configuration.thread_count = 2;
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

int32_t letter_vieneu_synthesize(
    letter_vieneu_engine *engine,
    const letter_vieneu_synthesis_options *options,
    letter_vieneu_audio *audio
) {
    clear_audio(audio);
    if (!engine || !options || !options->text || !audio) {
        return -1;
    }
    if (!engine->ready) {
        return -5;
    }

    VieneuV3OnnxParams params;
    params.text = options->text;
    params.voice_id = string_or_empty(options->voice_id);
    params.temperature = options->temperature;
    params.top_k = options->top_k;
    params.top_p = options->top_p;
    params.max_new_frames = options->maximum_frames;
    params.repetition_penalty = options->repetition_penalty;
    params.max_chars = options->maximum_characters;
    params.apply_watermark = false;

    std::vector<float> samples;
    engine->error.clear();
    if (!engine->runtime.synthesize(params, samples, engine->error)) {
        return -2;
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
