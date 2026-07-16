import AppKit
import SwiftUI

// MARK: - Window controller

final class DashboardWindowController: NSWindowController {
    static let shared = DashboardWindowController()

    private init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VinceSnap"
        window.contentViewController = NSHostingController(rootView: DashboardView())
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Main dashboard view

struct DashboardView: View {
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(WindowAction.sections.enumerated()), id: \.offset) { _, section in
                        sectionView(title: section.title, actions: section.actions)
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 460, height: 680)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("VinceSnap")
                    .font(.title.bold())
                Text("Made by KwanYuKim")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Version \(Bundle.main.shortVersion) — inspired by Rectangle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(20)
    }

    private func sectionView(title: String, actions: [WindowAction]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(actions, id: \.self) { action in
                HStack {
                    Text(action.title)
                    Spacer()
                    ShortcutRecorderButton(action: action)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Restore Defaults") {
                ShortcutManager.shared.restoreDefaults()
            }
            Spacer()
            Text("Click a shortcut, then press the new keys.\n⌫ clears the binding, ⎋ cancels.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
    }
}

// MARK: - Shortcut recorder

/// A button that shows an action's current shortcut; clicking it records
/// the next key combination pressed.
struct ShortcutRecorderButton: View {
    let action: WindowAction

    @State private var isRecording = false
    @State private var current: Shortcut?
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(label)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 96)
        }
        .tint(isRecording ? .accentColor : nil)
        .onAppear { current = ShortcutManager.shared.shortcut(for: action) }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutsChanged)) { _ in
            current = ShortcutManager.shared.shortcut(for: action)
        }
        .onDisappear { if isRecording { stopRecording() } }
    }

    private var label: String {
        if isRecording { return "Press keys…" }
        return current?.displayString ?? "—"
    }

    private func toggle() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        // Unregister our hotkeys so the combination being recorded isn't
        // swallowed by the existing binding.
        ShortcutManager.shared.pauseForRecording()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // swallow the event
        }
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case 53: // Escape — cancel
            stopRecording()
        case 51: // Delete — clear the binding
            ShortcutManager.shared.set(nil, for: action)
            stopRecording()
        default:
            guard let shortcut = Shortcut(event: event) else {
                NSSound.beep() // needs ⌃, ⌥ or ⌘
                return
            }
            ShortcutManager.shared.set(shortcut, for: action)
            stopRecording()
        }
    }

    private func stopRecording() {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        ShortcutManager.shared.resumeAfterRecording()
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
