import SwiftUI
import UniformTypeIdentifiers

struct AppRootView: View {
    @StateObject private var analyzer = MachoAnalyzer()
    @State private var selectedNode: DependencyNode?
    @State private var hasFile = false
    @State private var isDragTargeted = false

    var body: some View {
        Group {
            if hasFile || analyzer.isAnalyzing {
                mainLayout
            } else {
                LandingView(isDragTargeted: $isDragTargeted, onFilePicked: openFile)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            pickFile()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(
                analyzer: analyzer,
                selectedNode: $selectedNode,
                onReset: resetToLanding
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
        } detail: {
            if analyzer.isAnalyzing {
                loadingView
            } else if let node = selectedNode {
                DetailView(node: node)
            } else {
                placeholderDetail
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.accentColor)
            Text("Analyzing binary…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            Text("Select a module from the sidebar")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func openFile(_ path: String) {
        hasFile = true
        selectedNode = nil
        analyzer.analyze(atPath: path)
    }

    private func resetToLanding() {
        hasFile = false
        selectedNode = nil
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.title = "Select a Mach-O Binary"
        panel.allowedContentTypes = [.unixExecutable, .data]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            openFile(url.path)
        }
    }
}
