import SwiftUI
import UniformTypeIdentifiers

struct LandingView: View {
    @Binding var isDragTargeted: Bool
    var onFilePicked: (String) -> Void

    @State private var pulse = false
    @State private var rotateGlow = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0D0F1A"), Color(hex: "111827")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated radial glow behind the drop zone
            RadialGradient(
                colors: [Color(hex: "6366F1").opacity(isDragTargeted ? 0.35 : 0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .blendMode(.screen)
            .scaleEffect(pulse ? 1.1 : 0.95)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("MachoWalker")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "A78BFA"), Color(hex: "60A5FA")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("Mach-O Dependency Inspector for macOS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                dropZone
                    .frame(width: 460, height: 260)

                // Open button
                Button {
                    NotificationCenter.default.post(name: .openFilePicker, object: nil)
                } label: {
                    Label("Open Binary…", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "6366F1"))
                .keyboardShortcut("o")
            }
        }
        .onAppear { pulse = true }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "1E2235").opacity(isDragTargeted ? 0.95 : 0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isDragTargeted
                                ? LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "60A5FA")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isDragTargeted ? 2 : 1
                        )
                )

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "6366F1").opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: isDragTargeted ? "arrow.down.circle.fill" : "doc.viewfinder")
                        .font(.system(size: 38))
                        .foregroundStyle(
                            isDragTargeted
                                ? LinearGradient(colors: [Color(hex: "A78BFA"), Color(hex: "60A5FA")],
                                                 startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.3)],
                                                 startPoint: .top, endPoint: .bottom)
                        )
                        .scaleEffect(isDragTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isDragTargeted)
                }

                VStack(spacing: 6) {
                    Text(isDragTargeted ? "Release to analyze" : "Drop a Mach-O binary here")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Executables · .dylib · .framework · .bundle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .scaleEffect(isDragTargeted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { onFilePicked(url.path) }
            }
            return true
        }
    }
}

// MARK: - Color helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

