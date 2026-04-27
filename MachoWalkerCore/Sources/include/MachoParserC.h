#ifndef MachoParserC_h
#define MachoParserC_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MWAnalysisResult MWAnalysisResult;

MWAnalysisResult* mw_analyze(const char* path);

void mw_free_result(MWAnalysisResult* result);

const char* mw_get_architecture(const MWAnalysisResult* result);
const char* mw_get_uuid(const MWAnalysisResult* result);
uint32_t    mw_get_file_type(const MWAnalysisResult* result);
bool        mw_is_fat(const MWAnalysisResult* result);


uint32_t    mw_dependency_count(const MWAnalysisResult* result);
const char* mw_dependency_path(const MWAnalysisResult* result, uint32_t index);
bool        mw_dependency_is_weak(const MWAnalysisResult* result, uint32_t index);
bool        mw_dependency_is_reexport(const MWAnalysisResult* result, uint32_t index);

uint32_t    mw_rpath_count(const MWAnalysisResult* result);
const char* mw_rpath(const MWAnalysisResult* result, uint32_t index);

#ifdef __cplusplus
}
#endif

#endif /* MachoParserC_h */
