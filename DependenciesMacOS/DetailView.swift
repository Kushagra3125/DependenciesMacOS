import SwiftUI

struct DetailView: View {
    let node: DependencyNode

    @State private var selectedTab = 0
    @State private var symbolSearchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── Header card ──────────────────────────────────────────────
            headerCard

            Divider()

            // ── Tab bar ──────────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                    tabButton(label: tab.0, icon: tab.1, index: idx)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── Tab content ──────────────────────────────────────────────
            Group {
                switch selectedTab {
                case 0: dependenciesTab
                case 1: metadataTab
                case 2: rpathsTab
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(node.name)
    }

    private var tabs: [(String, String)] {
        [
            ("Dependencies", "arrow.triangle.branch"),
            ("Metadata",     "info.circle"),
            ("RPaths",       "point.bottomleft.filled.forward.to.point.topright.scurvepath")
        ]
    }

    // MARK: – Header card

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(statusGradient(for: node))
                    .frame(width: 54, height: 54)
                Image(systemName: headerIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Titles
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(node.name)
                        .font(.system(size: 20, weight: .bold))

                    if node.status == .missing {
                        missingBadge
                    } else if node.status == .loop {
                        loopBadge
                    }

                    if node.isFat {
                        Badge("Fat Binary", color: Color(hex: "6366F1"))
                    }
                    if node.isWeak {
                        Badge("weak", color: .orange)
                    }
                    if node.isReexport {
                        Badge("re-export", color: .purple)
                    }
                }

                Text(node.resolvedPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                if node.originalPath != node.resolvedPath {
                    Text("Originally: \(node.originalPath)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            // Quick stats pill
            if node.status == .found {
                VStack(alignment: .trailing, spacing: 6) {
                    statPill(value: "\(node.children?.count ?? 0)", label: "deps")
                    statPill(value: "\(node.rpaths.count)", label: "rpaths")
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var missingBadge: some View {
        Text("MISSING")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.red.opacity(0.15), in: Capsule())
            .foregroundStyle(.red)
    }

    private var loopBadge: some View {
        Text("CIRCULAR")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.yellow.opacity(0.15), in: Capsule())
            .foregroundStyle(.yellow)
    }

    private func statPill(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: – Dependencies tab

    private var dependenciesTab: some View {
        let deps = node.children ?? []
        return Group {
            if deps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "34D399"))
                    Text("No direct dependencies")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(deps) {
                    TableColumn("Status") { dep in
                        statusIcon(for: dep)
                    }
                    .width(50)

                    TableColumn("Name", value: \.name)

                    TableColumn("Architecture", value: \.architecture)
                        .width(90)

                    TableColumn("Kind") { dep in
                        if dep.isWeak { Badge("weak", color: .orange) }
                        else if dep.isReexport { Badge("re-export", color: .purple) }
                        else { Text("required").font(.caption).foregroundStyle(.secondary) }
                    }
                    .width(90)

                    TableColumn("Resolved Path") { dep in
                        Text(dep.resolvedPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for dep: DependencyNode) -> some View {
        let iconName = dep.status == .systemCached ? "building.columns.fill" : (dep.status == .missing ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        let iconColor = dep.status == .systemCached ? Color.blue : (dep.status == .missing ? .red : Color(hex: "34D399"))
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    // MARK: – Metadata tab

    @ViewBuilder
    private var metadataTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                metaSection("Binary Info") {
                    metaRow("Name",         node.name)
                    metaRow("Architecture", node.architecture)
                    metaRow("File Type",    node.fileTypeName)
                    metaRow("UUID",         node.uuid)
                    metaRow("Fat Binary",   node.isFat ? "Yes" : "No")
                }
                metaSection("Path Info") {
                    metaRow("Resolved Path",  node.resolvedPath)
                    metaRow("Original Path",  node.originalPath)
                }
            }
            .padding(.vertical, 12)
        }
    }

    func metaSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 6)
            content()
            Divider().padding(.horizontal, 20)
        }
    }

    func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            Text(value.isEmpty ? "–" : value)
                .font(.system(size: 13, design: value.count > 30 ? .monospaced : .default))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    // MARK: – RPaths tab

    @ViewBuilder
    private var rpathsTab: some View {
        if node.rpaths.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("No RPaths defined")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(node.rpaths, id: \.self) { rpath in
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color(hex: "6366F1"))
                    Text(rpath)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    // MARK: – Tab bar button

    private func tabButton(label: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                selectedTab == index
                    ? Color(hex: "6366F1").opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .foregroundStyle(selectedTab == index ? Color(hex: "A78BFA") : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Helpers

    private var headerIcon: String {
        switch node.status {
        case .found:   return node.fileTypeName.contains("Library") ? "swiftdata" : "terminal.fill"
        case .missing: return "exclamationmark.triangle.fill"
        case .loop:    return "arrow.2.circlepath"
        case .error:   return "xmark.circle.fill"
        case .systemCached: return "building.columns.fill"
        }
    }

    private func statusGradient(for node: DependencyNode) -> LinearGradient {
        switch node.status {
        case .found:   return LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "60A5FA")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
        case .missing: return LinearGradient(colors: [.red, Color(hex: "F97316")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
        case .loop:    return LinearGradient(colors: [.yellow, .orange],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
        case .error:   return LinearGradient(colors: [.gray, .gray.opacity(0.6)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
        case .systemCached: return LinearGradient(colors: [.blue, .cyan],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
