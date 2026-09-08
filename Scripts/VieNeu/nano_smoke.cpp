// Standalone integration checks; no Xcode test target is required.
#include "VieNeuNanoRuntime.h"
#include <chrono>
#include <cmath>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <vector>

static void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

static void writeWave(const std::string& path, const letter_nano_audio& audio) {
    std::ofstream output(path, std::ios::binary);
    require(static_cast<bool>(output), "Cannot write sample WAV");
    auto u16 = [&](uint16_t n) { output.put(n & 255); output.put(n >> 8); };
    auto u32 = [&](uint32_t n) { u16(n & 65535); u16(n >> 16); };
    output.write("RIFF", 4); u32(36 + audio.sample_count * 2); output.write("WAVEfmt ", 8);
    u32(16); u16(1); u16(1); u32(24000); u32(48000); u16(2); u16(16);
    output.write("data", 4); u32(audio.sample_count * 2);
    for (size_t i = 0; i < audio.sample_count; ++i) u16(static_cast<int16_t>(audio.samples[i] * 32767));
}

static std::vector<float> synthesize(letter_nano_engine *engine, const char *text,
                                     const char *voice, const std::string& output, int steps = 8) {
    auto *token = letter_nano_cancellation_create();
    require(token, "Cannot allocate cancellation");
    letter_nano_audio audio{};
    const auto start = std::chrono::steady_clock::now();
    const auto status = letter_nano_synthesize(engine, text, voice, steps, 42, token, &audio);
    letter_nano_cancellation_destroy(token);
    require(status == 0, letter_nano_last_error(engine));
    require(audio.sample_rate == 24000 && audio.sample_count > 2400, "Invalid waveform size/rate");
    double energy = 0;
    for (size_t i = 0; i < audio.sample_count; ++i) {
        require(std::isfinite(audio.samples[i]) && std::abs(audio.samples[i]) <= 1, "Invalid PCM");
        energy += audio.samples[i] * audio.samples[i];
    }
    require(energy / audio.sample_count > 1e-6, "Silent waveform");
    if (!output.empty()) writeWave(output, audio);
    const double wall = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    std::cout << "PASS voice=" << voice << " audio=" << audio.sample_count / 24000.0
              << "s wall=" << wall << "s" << std::endl;
    std::vector<float> result(audio.samples, audio.samples + audio.sample_count);
    letter_nano_audio_free(&audio);
    return result;
}

static void checkCancellation(letter_nano_engine *engine, bool duringRun) {
    auto *token = letter_nano_cancellation_create();
    require(token, "Cannot allocate cancellation");
    std::thread canceller;
    if (duringRun) {
        canceller = std::thread([token] {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            letter_nano_cancellation_request(token);
        });
    } else {
        letter_nano_cancellation_request(token);
    }
    letter_nano_audio audio{};
    const auto status = letter_nano_synthesize(engine,
        "Buổi sáng hôm ấy, mọi người cùng nhau đi dạo bên bờ sông và trò chuyện về những cuốn sách yêu thích.",
        "Adam", 16, 42, token, &audio);
    if (canceller.joinable()) canceller.join();
    letter_nano_cancellation_destroy(token);
    require(status == -2 && audio.samples == nullptr, "Cancellation did not stop synthesis");
    std::cout << "PASS cancellation " << (duringRun ? "during inference" : "before inference") << std::endl;
}

int main(int argc, char **argv) {
    try {
        require(argc == 4, "Usage: nano-smoke MODEL_DIRECTORY G2P_DICTIONARY OUTPUT_DIRECTORY");
        auto *missing = letter_nano_create("/missing-nano-model", argv[2], 1);
        require(missing && !letter_nano_is_ready(missing), "Missing assets must fail preparation");
        require(std::string(letter_nano_last_error(missing)).size() > 0, "Missing asset error lost");
        letter_nano_destroy(missing);
        auto *engine = letter_nano_create(argv[1], argv[2], 1);
        require(letter_nano_is_ready(engine), letter_nano_last_error(engine));
        const auto vietnamese = "Hôm nay trời đẹp. Tôi mở cuốn sách và bắt đầu đọc câu chuyện về một chuyến đi xa.";
        const auto first = synthesize(engine, vietnamese, "Adam", std::string(argv[3]) + "/nano-vietnamese.wav");
        synthesize(engine, "Ông Sherlock Holmes mở chiếc MacBook và đọc email của John Watson.",
                   "Trúc Ly", std::string(argv[3]) + "/nano-bilingual.wav");
        synthesize(engine, "[thở dài] Hôm nay tôi muốn nghỉ ngơi một chút rồi tiếp tục đọc sách.", "Mai Anh", "", 8);
        checkCancellation(engine, false);
        checkCancellation(engine, true);
        auto *token = letter_nano_cancellation_create();
        letter_nano_audio audio{};
        require(letter_nano_synthesize(engine, vietnamese, "Missing voice", 16, 42, token, &audio) == -1,
                "Unknown voice must fail");
        require(audio.samples == nullptr, "Failure must not expose stale audio");
        const std::string overlong(141, 'a');
        for (const auto *invalid : {"", overlong.c_str()}) {
            require(letter_nano_synthesize(engine, invalid, "Adam", 16, 42, token, &audio) == -1,
                    "Empty/overlong input must fail");
            require(audio.samples == nullptr, "Invalid input returned audio");
        }
        letter_nano_cancellation_destroy(token);
        const auto recovered = synthesize(engine, vietnamese, "Adam", "");
        require(first == recovered, "Cancellation/error recovery changed seeded output");
        letter_nano_destroy(engine);
        std::cout << "PASS all Nano integration checks" << std::endl;
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL " << error.what() << std::endl;
        return 1;
    }
}
