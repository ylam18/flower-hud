import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Sheet for adding or editing a command petal (open link / open file / system action / script).
struct CommandEditor: View {
    enum CommandType: String, CaseIterable, Identifiable {
        case openURL, openPath, systemAction, runScript
        var id: String { rawValue }
        var label: String {
            switch self {
            case .openURL:       return "Open Link"
            case .openPath:      return "Open File or Folder"
            case .systemAction:  return "System Action"
            case .runScript:     return "Run Script"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private let editingID: UUID
    private let isNew: Bool
    private let onSave: (PetalItem) -> Void

    @State private var type: CommandType
    @State private var name: String
    @State private var symbolName: String

    @State private var urlString: String
    @State private var openInApp: Bool
    @State private var targetApp: AppItem?

    @State private var pathURL: URL?

    @State private var systemAction: SystemAction

    @State private var scriptKind: ScriptKind
    @State private var scriptSource: String

    init(item: PetalItem?, onSave: @escaping (PetalItem) -> Void) {
        self.onSave = onSave
        self.editingID = item?.id ?? UUID()
        self.isNew = item == nil

        // Seed the form from the existing action (or sensible defaults for a new command).
        var t: CommandType = .openURL
        var url = ""; var inApp = false; var app: AppItem?
        var path: URL?
        var sys: SystemAction = .missionControl
        var kind: ScriptKind = .shell; var source = ""

        switch item?.action {
        case .openURL(let u, let a): t = .openURL; url = u.absoluteString; inApp = a != nil; app = a
        case .openPath(let p):       t = .openPath; path = p
        case .systemAction(let s):   t = .systemAction; sys = s
        case .runScript(let k, let s): t = .runScript; kind = k; source = s
        case .launchApp, .none:      break   // launchApp never reaches the command editor
        case .focusWindow, .newWindow: break // ephemeral drill-down actions, never persisted/edited
        }

        _type = State(initialValue: t)
        _name = State(initialValue: item?.name ?? "")
        _symbolName = State(initialValue: item?.symbolName ?? "")
        _urlString = State(initialValue: url)
        _openInApp = State(initialValue: inApp)
        _targetApp = State(initialValue: app)
        _pathURL = State(initialValue: path)
        _systemAction = State(initialValue: sys)
        _scriptKind = State(initialValue: kind)
        _scriptSource = State(initialValue: source)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Picker("Type", selection: $type) {
                    ForEach(CommandType.allCases) { Text($0.label).tag($0) }
                }

                switch type {
                case .openURL:      openURLFields
                case .openPath:     openPathFields
                case .systemAction: systemActionFields
                case .runScript:    runScriptFields
                }

                Section("Petal") {
                    TextField("Label", text: $name, prompt: Text(defaultName))
                    TextField("Icon (SF Symbol)", text: $symbolName, prompt: Text("optional, e.g. link"))
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 460, height: 420)
    }

    // MARK: - Type-specific fields

    @ViewBuilder private var openURLFields: some View {
        Section("Link") {
            TextField("URL", text: $urlString, prompt: Text("https://example.com or spotify:…"))
            Toggle("Open in a specific app", isOn: $openInApp)
            if openInApp {
                HStack {
                    Text(targetApp?.name ?? "No app chosen")
                        .foregroundStyle(targetApp == nil ? .secondary : .primary)
                    Spacer()
                    Button("Choose App…", action: chooseApp)
                }
            }
        }
    }

    @ViewBuilder private var openPathFields: some View {
        Section("File or Folder") {
            HStack {
                Text(pathURL?.path ?? "Nothing chosen")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(pathURL == nil ? .secondary : .primary)
                Spacer()
                Button("Choose…", action: choosePath)
            }
        }
    }

    @ViewBuilder private var systemActionFields: some View {
        Section("Action") {
            Picker("System action", selection: $systemAction) {
                ForEach(SystemAction.allCases) { Text($0.label).tag($0) }
            }
        }
    }

    @ViewBuilder private var runScriptFields: some View {
        Section("Script") {
            Picker("Interpreter", selection: $scriptKind) {
                ForEach(ScriptKind.allCases) { Text($0.label).tag($0) }
            }
            TextEditor(text: $scriptSource)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
            Text("Runs with your full user privileges. Only paste scripts you trust.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Logic

    private var isValid: Bool {
        switch type {
        case .openURL:      return normalizedURL(from: urlString) != nil
        case .openPath:     return pathURL != nil
        case .systemAction: return true
        case .runScript:    return !scriptSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var defaultName: String {
        switch type {
        case .openURL:
            if openInApp, let targetApp { return "Open in \(targetApp.name)" }
            return normalizedURL(from: urlString)?.host ?? "Open Link"
        case .openPath:     return pathURL?.lastPathComponent ?? "Open File"
        case .systemAction: return systemAction.label
        case .runScript:    return "Run Script"
        }
    }

    private func save() {
        let action: PetalAction
        switch type {
        case .openURL:
            guard let url = normalizedURL(from: urlString) else { return }
            action = .openURL(url: url, inApp: openInApp ? targetApp : nil)
        case .openPath:
            guard let pathURL else { return }
            action = .openPath(url: pathURL)
        case .systemAction:
            action = .systemAction(systemAction)
        case .runScript:
            action = .runScript(kind: scriptKind, source: scriptSource)
        }

        let label = name.trimmingCharacters(in: .whitespaces)
        let symbol = symbolName.trimmingCharacters(in: .whitespaces)
        let item = PetalItem(
            id: editingID,
            name: label.isEmpty ? defaultName : label,
            action: action,
            symbolName: symbol.isEmpty ? nil : symbol
        )
        onSave(item)
        dismiss()
    }

    /// Accepts schemeful URLs (web or app deep links); prepends https:// for bare hosts.
    private func normalizedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            targetApp = AppItem(url: url)
        }
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            pathURL = url
        }
    }
}
