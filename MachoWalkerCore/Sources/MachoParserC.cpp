

#include "private/MachoParser.hpp"
#include "include/MachoParserC.h"
#include <new>

using namespace MachoWalker;

struct MWAnalysisResult {
    MachoAnalysis analysis;
};

MWAnalysisResult* mw_analyze(const char* path) {
    if (!path) return nullptr;
    MachoParser parser{std::string{path}};
    auto result = parser.analyze();
    if (!result.has_value()) return nullptr;
    auto* ptr = new (std::nothrow) MWAnalysisResult();
    if (!ptr) return nullptr;
    ptr->analysis = std::move(*result);
    return ptr;
}

void mw_free_result(MWAnalysisResult* result) {
    delete result;
}

const char* mw_get_architecture(const MWAnalysisResult* result) {
    if (!result) return nullptr;
    return result->analysis.architecture.c_str();
}

const char* mw_get_uuid(const MWAnalysisResult* result) {
    if (!result) return nullptr;
    return result->analysis.uuid.c_str();
}

uint32_t mw_get_file_type(const MWAnalysisResult* result) {
    if (!result) return 0;
    return result->analysis.fileType;
}

bool mw_is_fat(const MWAnalysisResult* result) {
    if (!result) return false;
    return result->analysis.isFatBinary;
}

uint32_t mw_dependency_count(const MWAnalysisResult* result) {
    if (!result) return 0;
    return static_cast<uint32_t>(result->analysis.dependencies.size());
}

const char* mw_dependency_path(const MWAnalysisResult* result, uint32_t index) {
    if (!result || index >= result->analysis.dependencies.size()) return nullptr;
    return result->analysis.dependencies[index].path.c_str();
}

bool mw_dependency_is_weak(const MWAnalysisResult* result, uint32_t index) {
    if (!result || index >= result->analysis.dependencies.size()) return false;
    return result->analysis.dependencies[index].isWeak;
}

bool mw_dependency_is_reexport(const MWAnalysisResult* result, uint32_t index) {
    if (!result || index >= result->analysis.dependencies.size()) return false;
    return result->analysis.dependencies[index].isReexport;
}

uint32_t mw_rpath_count(const MWAnalysisResult* result) {
    if (!result) return 0;
    return static_cast<uint32_t>(result->analysis.rpaths.size());
}

const char* mw_rpath(const MWAnalysisResult* result, uint32_t index) {
    if (!result || index >= result->analysis.rpaths.size()) return nullptr;
    return result->analysis.rpaths[index].c_str();
}
