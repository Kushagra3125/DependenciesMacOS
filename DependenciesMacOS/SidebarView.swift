import SwiftUI

struct SidebarView: View {
    @ObservedObject var analyzer: MachoAnalyzer
    @Binding var selectedNode: DependencyNode?
    var onReset: () -> Void

    @State private var searchText = ""
    @State private var filterMissingOnly = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Filter modules…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)

            // Missing-only toggle
            Toggle(isOn: $filterMissingOnly) {
                Label("Show missing only", systemImage: "exclamationmark.triangle")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            Divider()

            // Tree
            if let root = analyzer.rootNode {
                List(selection: $selectedNode) {
                    let visible = filterNode(root)
                    if let visible {
                        treeRow(for: visible)
                    }
                }
                .listStyle(.sidebar)
            } else {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            }

            // Footer
            sidebarFooter
        }
        .navigationTitle("Modules")
    }

    // MARK: - Recursive Tree Rows

    @ViewBuilder
    private func treeRow(for node: DependencyNode) -> some View {
        if let children = node.children, !children.isEmpty {
            let filtered = children.compactMap { filterNode($0) }
            if !filtered.isEmpty {
                OutlineGroup(
                    [node],
                    children: \.children,
                    content: { n in moduleRow(n) }
                )
            } else {
                moduleRow(node).tag(node)
            }
        } else {
            moduleRow(node).tag(node)
        }
    }

    private func moduleRow(_ node: DependencyNode) -> some View {
        HStack(spacing: 8) {
            statusIcon(for: node)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(node.status == .missing ? Color.red : .primary)
                    .lineLimit(1)
                if node.status == .found {
                    Text(node.architecture)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            badges(for: node)
        }
        .tag(node)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusIcon(for node: DependencyNode) -> some View {
        ZStack {
            Circle()
                .fill(iconBGColor(for: node))
                .frame(width: 26, height: 26)
            Image(systemName: iconName(for: node))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconFGColor(for: node))
        }
    }

    @ViewBuilder
    private func badges(for node: DependencyNode) -> some View {
        HStack(spacing: 4) {
            if node.isWeak {
                Badge("weak", color: .orange)
            }
            if node.isReexport {
                Badge("re-export", color: .purple)
            }
            if node.status == .loop {
                Badge("loop", color: .yellow)
            }
        }
    }

    // MARK: - Header / Footer

    private var sidebarHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(analyzer.rootNode?.name ?? "Analyzing…")
                    .font(.headline)
                    .lineLimit(1)
                if let root = analyzer.rootNode {
                    Text(root.architecture + (root.isFat ? " · Fat Binary" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onReset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Open a new binary")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sidebarFooter: some View {
        Group {
            if let root = analyzer.rootNode {
                let totalCount = totalModules(root)
                let missingCount = missingModules(root)
                Divider()
                HStack {
                    Label("\(totalCount) modules", systemImage: "square.stack.3d.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if missingCount > 0 {
                        Label("\(missingCount) missing", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Filtering

    private func filterNode(_ node: DependencyNode) -> DependencyNode? {
        let matchesSearch = searchText.isEmpty || node.name.localizedCaseInsensitiveContains(searchText) || node.resolvedPath.localizedCaseInsensitiveContains(searchText)
        let matchesMissing = !filterMissingOnly || node.status == .missing

        let filteredChildren = node.children?.compactMap { filterNode($0) }
        let hasVisibleChildren = !(filteredChildren?.isEmpty ?? true)

        if (matchesSearch && matchesMissing) || hasVisibleChildren {
            var copy = node
            copy.children = filteredChildren.flatMap { $0.isEmpty ? nil : $0 }
            return copy
        }
        return nil
    }

    // MARK: - Stats

    private func totalModules(_ node: DependencyNode) -> Int {
        1 + (node.children?.reduce(0) { $0 + totalModules($1) } ?? 0)
    }

    private func missingModules(_ node: DependencyNode) -> Int {
        let self_ = node.status == .missing ? 1 : 0
        return self_ + (node.children?.reduce(0) { $0 + missingModules($1) } ?? 0)
    }

    // MARK: - Icon helpers

    private func iconName(for node: DependencyNode) -> String {
        switch node.status {
        case .found:    return "doc.fill"
        case .missing:  return "exclamationmark.triangle.fill"
        case .loop:     return "arrow.2.circlepath"
        case .error:    return "xmark.circle.fill"
        case .systemCached: return "building.columns.fill"
        }
    }

    private func iconBGColor(for node: DependencyNode) -> Color {
        switch node.status {
        case .found:   return Color(hex: "6366F1").opacity(0.15)
        case .missing: return Color.red.opacity(0.15)
        case .loop:    return Color.yellow.opacity(0.15)
        case .error:   return Color.gray.opacity(0.15)
        case .systemCached: return Color.blue.opacity(0.15)
        }
    }

    private func iconFGColor(for node: DependencyNode) -> Color {
        switch node.status {
        case .found:   return Color(hex: "A78BFA")
        case .missing: return .red
        case .loop:    return .yellow
        case .error:   return .gray
        case .systemCached: return .blue
        }
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

// Needed to make filtering work on value types
extension DependencyNode {
    var childrenMutable: [DependencyNode]? {
        get { children }
        set { children = newValue }
    }
}
