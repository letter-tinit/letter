#ifndef VIENEU_H
#define VIENEU_H

#include <string>
#include <vector>

class VieneuProfile {
public:
    static void configure_phonemizer_dictionary(const std::string& path);
    static std::string format_prompt(const std::string& phonemes);
    static std::vector<int64_t> extract_speech_ids(const std::string& generated_text);

    // Rule-based Vietnamese G2P
    static std::string phonemize(const std::string& text);

};

#endif // VIENEU_H
