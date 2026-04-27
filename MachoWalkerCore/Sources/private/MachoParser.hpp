#ifndef MachoParser_hpp
#define MachoParser_hpp

#include <string>
#include <vector>
#include <optional>

namespace MachoWalker {

struct DylibInfo {
    std::string path;
    uint32_t currentVersion;
    uint32_t compatibilityVersion;
    bool isWeak;
    bool isReexport;
};

struct MachoAnalysis {
    std::string architecture;
    uint32_t fileType;
    std::vector<DylibInfo> dependencies;
    std::vector<std::string> rpaths;
    std::string uuid;
    bool isFatBinary;
    bool is64Bit;
};

class MachoParser {
public:
    explicit MachoParser(const std::string& filePath);
    ~MachoParser();

    std::optional<MachoAnalysis> analyze();

private:
    std::string filePath_;
    std::optional<MachoAnalysis> parseThin(uint64_t offset, uint32_t magic);
};

} // namespace MachoWalker

#endif /* MachoParser_hpp */
