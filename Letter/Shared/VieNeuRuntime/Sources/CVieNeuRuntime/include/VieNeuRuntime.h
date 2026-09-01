#ifndef LETTER_VIENEU_RUNTIME_H
#define LETTER_VIENEU_RUNTIME_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct letter_vieneu_engine letter_vieneu_engine;
typedef struct letter_vieneu_cancellation letter_vieneu_cancellation;

typedef int32_t (*letter_vieneu_audio_chunk_callback)(
    const float *samples,
    size_t sample_count,
    int32_t sample_rate,
    void *context
);

typedef struct letter_vieneu_configuration {
    const char *model_directory;
    const char *onnx_directory;
    const char *codec_directory;
    const char *voices_json_path;
    const char *g2p_dictionary_path;
    int32_t thread_count;
} letter_vieneu_configuration;

typedef struct letter_vieneu_synthesis_options {
    const char *text;
    const char *voice_id;
    float temperature;
    int32_t top_k;
    float top_p;
    int32_t maximum_frames;
    float repetition_penalty;
    int32_t maximum_characters;
    float playback_rate;
} letter_vieneu_synthesis_options;

typedef struct letter_vieneu_audio {
    float *samples;
    size_t sample_count;
    int32_t sample_rate;
} letter_vieneu_audio;

letter_vieneu_configuration letter_vieneu_default_configuration(void);
letter_vieneu_synthesis_options letter_vieneu_default_synthesis_options(void);

letter_vieneu_engine *letter_vieneu_create(
    const letter_vieneu_configuration *configuration
);

void letter_vieneu_destroy(letter_vieneu_engine *engine);

int32_t letter_vieneu_is_ready(const letter_vieneu_engine *engine);

letter_vieneu_cancellation *letter_vieneu_cancellation_create(void);

void letter_vieneu_cancellation_request(
    letter_vieneu_cancellation *cancellation
);

int32_t letter_vieneu_cancellation_is_requested(
    const letter_vieneu_cancellation *cancellation
);

void letter_vieneu_cancellation_destroy(
    letter_vieneu_cancellation *cancellation
);

int32_t letter_vieneu_synthesize(
    letter_vieneu_engine *engine,
    const letter_vieneu_synthesis_options *options,
    const letter_vieneu_cancellation *cancellation,
    letter_vieneu_audio *audio
);

int32_t letter_vieneu_synthesize_stream(
    letter_vieneu_engine *engine,
    const letter_vieneu_synthesis_options *options,
    const letter_vieneu_cancellation *cancellation,
    letter_vieneu_audio_chunk_callback callback,
    void *context
);

void letter_vieneu_audio_free(letter_vieneu_audio *audio);

const char *letter_vieneu_last_error(const letter_vieneu_engine *engine);

#ifdef __cplusplus
}
#endif

#endif
