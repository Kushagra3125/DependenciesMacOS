# DependenciesMacOS (MachoWalker)

A SwiftUI macOS app that inspects **Mach-O** binaries and visualizes their dynamic library dependencies.

It uses the `MachoWalkerCore` Swift Package (C++ + C interface) to parse Mach-O load commands, then builds a dependency tree with basic `@rpath`, `@loader_path`, and `@executable_path` resolution.

## Features

- Drag & drop a Mach-O binary (executables, `.dylib`, `.framework`, `.bundle`)
- Dependency tree view with status (found / missing / loop / system cached)
- Shows architecture, UUID, file type, and per-binary `LC_RPATH` entries
- Marks weak and re-exported dependencies when present

## Requirements

- macOS 14+
- Xcode 15+ (Swift tools 5.9)

## Build & Run

1. Open `DependenciesMacOS.xcodeproj` in Xcode.
2. Select the `DependenciesMacOS` scheme.
3. Build & Run (`⌘R`).
4. Drop a Mach-O binary into the app (or use **Open Binary…**).

## How it Works (High level)

- `DependenciesMacOS` (SwiftUI app)
  - `MachoAnalyzer` calls into `MachoWalkerCore` and resolves paths/rpaths.
- `MachoWalkerCore` (Swift Package)
  - C++ parser reads Mach-O headers and `LC_LOAD_*DYLIB`, `LC_RPATH`, `LC_UUID`.
  - Exposes a small C API used from Swift.

## Notes / Limitations

- The core parser currently supports **64-bit** Mach-O parsing.
- Some Apple-shipped dylibs/frameworks may not exist as standalone files (they can be in the **dyld shared cache**); these may appear as “System (cached)”.
- Recursion depth is capped (see `MachoAnalyzer`).

## Repo Layout

- `DependenciesMacOS/` — SwiftUI app sources
- `MachoWalkerCore/` — Swift Package (C++ / C headers)

