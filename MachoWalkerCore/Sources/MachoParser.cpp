#include <iostream>
#include <fstream>
#include <cstring>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach-o/nlist.h>
#include <uuid/uuid.h>
#include "private/MachoParser.hpp"

namespace MachoWalker {

MachoParser::MachoParser(const std::string& filePath) : filePath_(filePath) {}
MachoParser::~MachoParser() {}

std::optional<MachoAnalysis> MachoParser::parseThin(uint64_t offset, uint32_t magic) {
    std::ifstream file(filePath_, std::ios::binary);
    if (!file.is_open()) return std::nullopt;

    file.seekg(static_cast<std::streamoff>(offset));

    bool is64 = (magic == MH_MAGIC_64 || magic == MH_CIGAM_64);
    bool needSwap = (magic == MH_CIGAM || magic == MH_CIGAM_64 ||
                     magic == FAT_CIGAM);

    if (!is64) return std::nullopt; // Only supporting 64-bit for now

    mach_header_64 header;
    file.read(reinterpret_cast<char*>(&header), sizeof(header));

    MachoAnalysis result;
    result.is64Bit = true;
    result.isFatBinary = false;

    result.architecture = (header.cputype == CPU_TYPE_X86_64) ? "x86_64" :
                          (header.cputype == CPU_TYPE_ARM64)  ? "arm64" :
                                                                 "unknown";
    result.fileType = header.filetype;

    for (uint32_t i = 0; i < header.ncmds; ++i) {
        std::streampos cmdPos = file.tellg();
        load_command cmd;
        file.read(reinterpret_cast<char*>(&cmd), sizeof(cmd));

        if (cmd.cmdsize == 0) break;

        if (cmd.cmd == LC_LOAD_DYLIB ||
            cmd.cmd == LC_LOAD_WEAK_DYLIB ||
            cmd.cmd == LC_REEXPORT_DYLIB ||
            cmd.cmd == LC_LOAD_UPWARD_DYLIB) {

            file.seekg(cmdPos);
            dylib_command dc;
            file.read(reinterpret_cast<char*>(&dc), sizeof(dc));

            file.seekg(cmdPos + static_cast<std::streamoff>(dc.dylib.name.offset));
            std::string name;
            std::getline(file, name, '\0');

            DylibInfo info;
            info.path = name;
            info.currentVersion = dc.dylib.current_version;
            info.compatibilityVersion = dc.dylib.compatibility_version;
            info.isWeak = (cmd.cmd == LC_LOAD_WEAK_DYLIB);
            info.isReexport = (cmd.cmd == LC_REEXPORT_DYLIB);
            result.dependencies.push_back(info);

        } else if (cmd.cmd == LC_RPATH) {
            file.seekg(cmdPos);
            rpath_command rc;
            file.read(reinterpret_cast<char*>(&rc), sizeof(rc));
            file.seekg(cmdPos + static_cast<std::streamoff>(rc.path.offset));
            std::string rpath;
            std::getline(file, rpath, '\0');
            result.rpaths.push_back(rpath);

        } else if (cmd.cmd == LC_UUID) {
            file.seekg(cmdPos);
            uuid_command uc;
            file.read(reinterpret_cast<char*>(&uc), sizeof(uc));
            char uuidStr[37];
            uuid_unparse_upper(uc.uuid, uuidStr);
            result.uuid = uuidStr;
        }

        file.seekg(cmdPos + static_cast<std::streamoff>(cmd.cmdsize));
    }

    return result;
}

std::optional<MachoAnalysis> MachoParser::analyze() {
    std::ifstream file(filePath_, std::ios::binary);
    if (!file.is_open()) return std::nullopt;

    uint32_t magic;
    file.read(reinterpret_cast<char*>(&magic), sizeof(magic));
    file.close();

    // Fat binary
    if (magic == FAT_MAGIC || magic == FAT_CIGAM) {
        std::ifstream fatFile(filePath_, std::ios::binary);
        fat_header fatHdr;
        fatFile.read(reinterpret_cast<char*>(&fatHdr), sizeof(fatHdr));

        uint32_t narch = (magic == FAT_CIGAM) ? __builtin_bswap32(fatHdr.nfat_arch) : fatHdr.nfat_arch;
        for (uint32_t i = 0; i < narch; ++i) {
            fat_arch arch;
            fatFile.read(reinterpret_cast<char*>(&arch), sizeof(arch));
            uint32_t off = (magic == FAT_CIGAM) ? __builtin_bswap32(arch.offset) : arch.offset;

            std::ifstream archFile(filePath_, std::ios::binary);
            archFile.seekg(off);
            uint32_t archMagic;
            archFile.read(reinterpret_cast<char*>(&archMagic), sizeof(archMagic));
            archFile.close();

            if (auto r = parseThin(off, archMagic)) {
                r->isFatBinary = true;
                return r;
            }
        }
        return std::nullopt;
    }

    return parseThin(0, magic);
}

} // namespace MachoWalker
