import Foundation
import MachoWalkerCore
import SwiftUI
import Combine
// MARK: - Data Models

public enum NodeStatus {
    case found
    case missing
    case loop     // Circular dependency detected
    case error    // Could not parse
    case systemCached
}

public struct DependencyNode: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let resolvedPath: String   // Path after @rpath/etc resolution
    public let originalPath: String   // Raw path from load command
    public let architecture: String
    public let uuid: String
    public let fileTypeName: String
    public let isFat: Bool
    public var rpaths: [String]
    public var children: [DependencyNode]?
    public var status: NodeStatus
    public var isWeak: Bool
    public var isReexport: Bool

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: DependencyNode, rhs: DependencyNode) -> Bool { lhs.id == rhs.id }
}

// MARK: - File Type Name

func fileTypeName(_ type: UInt32) -> String {
    switch Int32(type) {
    case 0x1: return "Object"
    case 0x2: return "Executable"
    case 0x6: return "Dynamic Library"
    case 0x7: return "Bundle"
    case 0x8: return "Dynamic Linker"
    default:  return "Mach-O (\(type))"
    }
}

// MARK: - Analyzer

@MainActor
public class MachoAnalyzer: ObservableObject {
    @Published public var rootNode: DependencyNode?
    @Published public var isAnalyzing: Bool = false
    @Published public var errorMessage: String?

    private var executableDir: String = ""

    public init() {}

    public func analyze(atPath path: String) {
        isAnalyzing = true
        rootNode = nil
        errorMessage = nil
        executableDir = (path as NSString).deletingLastPathComponent

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let execDir = await self.executableDir
            var visited = Set<String>()          // ← mutable local, safe to pass inout
            let node = Self.analyzeNode(
                originalPath: path,
                loaderDir: execDir,
                execDir: execDir,
                inheritedRPaths: [],
                visited: &visited,
                depth: 0,
                maxDepth: 6
            )
            await MainActor.run {
                self.rootNode = node
                self.isAnalyzing = false
            }
        }
    }

    // MARK: - Recursive Parser

    nonisolated private static func analyzeNode(
        originalPath: String,
        loaderDir: String,
        execDir: String,
        inheritedRPaths: [String],
        visited: inout Set<String>,
        depth: Int,
        maxDepth: Int
    ) -> DependencyNode {
        let resolvedPath = resolvePath(originalPath, loaderDir: loaderDir, execDir: execDir, rpaths: inheritedRPaths)
        let name = URL(fileURLWithPath: resolvedPath).lastPathComponent

        // Circular dependency guard
        if visited.contains(resolvedPath) {
            return DependencyNode(
                name: name, resolvedPath: resolvedPath, originalPath: originalPath,
                architecture: "–", uuid: "–", fileTypeName: "–", isFat: false,
                rpaths: [], children: nil, status: .loop, isWeak: false, isReexport: false
            )
        }

        // Missing file
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            if isLikelySystemCached(path: resolvedPath) {
                return DependencyNode(
                    name: name, resolvedPath: resolvedPath, originalPath: originalPath,
                    architecture: "–", uuid: "–", fileTypeName: "System (cached)", isFat: false,
                    rpaths: [], children: nil, status: .systemCached, isWeak: false, isReexport: false
                )
            }
            return DependencyNode(
                name: name, resolvedPath: resolvedPath, originalPath: originalPath,
                architecture: "–", uuid: "–", fileTypeName: "Missing", isFat: false,
                rpaths: [], children: nil, status: .missing, isWeak: false, isReexport: false
            )
        }

        // Parse the binary
        guard let result = mw_analyze(resolvedPath) else {
            return DependencyNode(
                name: name, resolvedPath: resolvedPath, originalPath: originalPath,
                architecture: "–", uuid: "–", fileTypeName: "Parse Error", isFat: false,
                rpaths: [], children: nil, status: .error, isWeak: false, isReexport: false
            )
        }
        defer { mw_free_result(result) }

        let arch     = String(cString: mw_get_architecture(result))
        let uuid     = String(cString: mw_get_uuid(result))
        let fileType = fileTypeName(mw_get_file_type(result))
        let isFat    = mw_is_fat(result)

        // Collect RPaths from this binary
        var ownRPaths: [String] = []
        for i in 0 ..< mw_rpath_count(result) {
            if let raw = mw_rpath(result, i) {
                let rp = resolvePath(String(cString: raw), loaderDir: (resolvedPath as NSString).deletingLastPathComponent, execDir: execDir, rpaths: inheritedRPaths)
                ownRPaths.append(rp)
            }
        }
        let combinedRPaths = ownRPaths + inheritedRPaths

        visited.insert(resolvedPath)
        let currentLoaderDir = (resolvedPath as NSString).deletingLastPathComponent

        // Recurse into children
        var children: [DependencyNode] = []
        if depth < maxDepth {
            for i in 0 ..< mw_dependency_count(result) {
                guard let rawPath = mw_dependency_path(result, i) else { continue }
                let depOriginal = String(cString: rawPath)
                let isWeak    = mw_dependency_is_weak(result, i)
                let isReexport = mw_dependency_is_reexport(result, i)

                var child = analyzeNode(
                    originalPath: depOriginal,
                    loaderDir: currentLoaderDir,
                    execDir: execDir,
                    inheritedRPaths: combinedRPaths,
                    visited: &visited,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
                child.isWeak = isWeak
                child.isReexport = isReexport
                children.append(child)
            }
        }

        return DependencyNode(
            name: name,
            resolvedPath: resolvedPath,
            originalPath: originalPath,
            architecture: arch,
            uuid: uuid,
            fileTypeName: fileType,
            isFat: isFat,
            rpaths: ownRPaths,
            children: children.isEmpty ? nil : children,
            status: .found,
            isWeak: false,
            isReexport: false
        )
    }

    // MARK: - Path Resolution

    nonisolated static func resolvePath(_ path: String, loaderDir: String, execDir: String, rpaths: [String]) -> String {
        let fm = FileManager.default
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("@executable_path") {
            let resolved = trimmed.replacingOccurrences(of: "@executable_path", with: execDir)
            return (resolved as NSString).standardizingPath
        }

        if trimmed.hasPrefix("@loader_path") {
            let resolved = trimmed.replacingOccurrences(of: "@loader_path", with: loaderDir)
            return (resolved as NSString).standardizingPath
        }

        if trimmed.hasPrefix("@rpath") {
            let suffix = String(trimmed.dropFirst("@rpath".count)) // e.g. "/libFoo.dylib"
            for rpath in rpaths {
                let candidate = ((rpath + suffix) as NSString).standardizingPath
                if fm.fileExists(atPath: candidate) { return candidate }
            }
            // Fallback: common system locations
            for base in ["/usr/lib", "/usr/lib/swift", "/usr/local/lib", "/opt/homebrew/lib",
                         "/System/Library/Frameworks", "/Library/Frameworks", execDir, loaderDir] {
                let candidate = ((base + suffix) as NSString).standardizingPath
                if fm.fileExists(atPath: candidate) { return candidate }
            }
            // Return best-guess (will show as missing)
            return rpaths.first.map { (($0 + suffix) as NSString).standardizingPath } ?? trimmed
        }

        // If we got a bare name (no path separators), try common dylib locations.
        if !trimmed.contains("/") && !trimmed.hasPrefix("@") {
            for base in [loaderDir, execDir, "/usr/lib", "/usr/local/lib", "/opt/homebrew/lib"] {
                let candidate = ((base + "/" + trimmed) as NSString).standardizingPath
                if fm.fileExists(atPath: candidate) { return candidate }
            }
        }

        return (trimmed as NSString).standardizingPath
    }

    nonisolated private static func isLikelySystemCached(path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        // Many Apple-shipped dylibs/framework binaries are in the dyld shared cache and may not exist as standalone files.
        // Treat these as "system cached" instead of "missing".
        let systemPrefixes = [
            "/usr/lib/",
            "/usr/lib/swift/",
            "/System/Library/",
            "/Library/Apple/System/"
        ]
        return systemPrefixes.contains { standardized.hasPrefix($0) }
    }
}
