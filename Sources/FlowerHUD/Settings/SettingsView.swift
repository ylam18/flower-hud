import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: PresetStore

    var body: some View {
        TabView {
            GeneralTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
            AppsTab(store: store)
                .tabItem { Label("Items", systemImage: "square.grid.2x2") }
            ThemeTab(store: store)
                .tabItem { Label("Theme", systemImage: "paintpalette") }
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var store: PresetStore
    @State private var trusted = Accessibility.isTrusted
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("Trigger") {
                HStack {
                    Text("Hold to open the flower:")
                    Spacer()
                    TriggerRecorder(trigger: $store.trigger)
                }
                Text("Hold the trigger, move toward an app, and release to open it. Side mouse buttons or an unused key work best — a primary button or typing key will be intercepted while bound.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Accessibility access") {
                HStack {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Granted — the trigger is active." : "Not granted — the trigger can’t be detected.")
                    Spacer()
                    if !trusted {
                        Button("Open Settings") { Accessibility.openSettings() }
                    }
                    Button("Refresh") { trusted = Accessibility.isTrusted }
                }
                if !trusted {
                    Text("Turn on Flower in System Settings ▸ Privacy & Security ▸ Accessibility. The trigger activates automatically once access is granted — no need to relaunch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Startup") {
                Toggle("Launch Flower at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LoginItem.setEnabled($0) }
            }
        }
        .formStyle(.grouped)
        .onAppear { trusted = Accessibility.isTrusted; launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - Apps

private struct AppsTab: View {
    @ObservedObject var store: PresetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("App source", selection: $store.sourceMode) {
                ForEach(SourceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            switch store.sourceMode {
            case .dock:
                DockPreview()
            case .custom:
                CustomPresetEditor(store: store)
            }
        }
    }
}

// MARK: - Theme

private struct ThemeTab: View {
    @ObservedObject var store: PresetStore

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 160), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick a look for the flower. Changes apply the next time you open it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(FlowerTheme.all) { theme in
                        ThemeCard(theme: theme, selected: store.themeID == theme.id)
                            .onTapGesture { store.theme = theme }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
}

/// A selectable card: a mini flower preview over a neutral backdrop (so translucent material
/// themes read correctly), the theme's name, and a selection ring.
private struct ThemeCard: View {
    let theme: FlowerTheme
    let selected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ThemePreview(theme: theme)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .background(backdrop)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(theme.name)
                .font(.callout)
                .fontWeight(selected ? .semibold : .regular)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.12) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.20),
                              lineWidth: selected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A soft neutral gradient stands in for "whatever is behind the overlay" so material
    /// themes show their translucency instead of rendering on a flat panel color.
    private var backdrop: some View {
        LinearGradient(
            colors: [Color(white: 0.30), Color(white: 0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// Three petals around a hub, painted with a theme — the same elements `FlowerView` draws,
/// at a glanceable size. The center-right petal is shown highlighted.
private struct ThemePreview: View {
    let theme: FlowerTheme

    private let petal: CGFloat = 30

    var body: some View {
        ZStack {
            previewPetal(symbol: "globe", highlighted: false).offset(x: -26, y: -8)
            previewPetal(symbol: "folder", highlighted: false).offset(x: 26, y: -8)
            previewPetal(symbol: "star.fill", highlighted: true).offset(x: 0, y: -22)

            Text("Safari")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.hubText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.hubBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.hubBorder, lineWidth: 1))
                .offset(y: 24)
        }
    }

    private func previewPetal(symbol: String, highlighted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(fillStyle)
                .overlay(tint)
                .overlay(
                    Circle().strokeBorder(
                        highlighted ? theme.highlightStroke : theme.petalStroke,
                        lineWidth: highlighted ? theme.highlightStrokeWidth : theme.petalStrokeWidth
                    )
                )
                .shadow(color: theme.petalShadow, radius: 3, y: 1)
            Image(systemName: symbol)
                .resizable().scaledToFit()
                .fontWeight(.medium)
                .foregroundStyle(theme.symbolColor)
                .frame(width: petal * 0.46, height: petal * 0.46)
        }
        .frame(width: petal, height: petal)
    }

    private var fillStyle: AnyShapeStyle {
        switch theme.petalFill {
        case .material:
            return AnyShapeStyle(.ultraThinMaterial)
        case .solid(let color):
            return AnyShapeStyle(color)
        case .gradient(let top, let bottom):
            return AnyShapeStyle(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
        }
    }

    @ViewBuilder
    private var tint: some View {
        if case .material(let t?) = theme.petalFill {
            Circle().fill(t)
        }
    }
}

private struct DockPreview: View {
    @State private var apps: [AppItem] = DockReader.read()

    var body: some View {
        VStack(alignment: .leading) {
            Text("These are read live from your Dock:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            if apps.isEmpty {
                ContentUnavailablePlaceholder(text: "Couldn’t read Dock apps. Switch to a custom preset to choose apps manually.")
            } else {
                List(apps) { app in AppRow(app: app) }
            }
            HStack {
                Spacer()
                Button("Reload") { apps = DockReader.read() }
            }
            .padding([.horizontal, .bottom])
        }
        .onAppear { apps = DockReader.read() }
    }
}

private struct CustomPresetEditor: View {
    @ObservedObject var store: PresetStore
    /// The command currently being edited in the sheet, or nil.
    @State private var editingItem: PetalItem?
    @State private var showingNewCommand = false

    var body: some View {
        VStack {
            if store.customItems.isEmpty {
                ContentUnavailablePlaceholder(text: "Nothing here yet. Use “Add ▾” to add apps and commands to your flower.")
            } else {
                List {
                    ForEach(Array(store.customItems.enumerated()), id: \.element.id) { index, item in
                        ItemRow(item: item)
                            .contentShape(Rectangle())
                            .contextMenu {
                                if item.isCommand {
                                    Button("Edit…") { editingItem = item }
                                }
                                Button("Remove", role: .destructive) {
                                    store.customItems.remove(at: index)
                                }
                            }
                    }
                    .onMove { store.customItems.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { store.customItems.remove(atOffsets: $0) }
                }
            }
            HStack {
                Menu("Add") {
                    Button("Add App…", action: addApp)
                    Button("Add Command…") { showingNewCommand = true }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                Text("Drag to reorder • right-click to edit • swipe / Delete to remove")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .bottom])
        }
        // New command.
        .sheet(isPresented: $showingNewCommand) {
            CommandEditor(item: nil) { newItem in
                store.customItems.append(newItem)
            }
        }
        // Edit existing command.
        .sheet(item: $editingItem) { editing in
            CommandEditor(item: editing) { updated in
                if let i = store.customItems.firstIndex(where: { $0.id == updated.id }) {
                    store.customItems[i] = updated
                }
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
            for url in panel.urls where !store.customItems.contains(where: { $0.appURL == url }) {
                store.customItems.append(.app(AppItem(url: url)))
            }
        }
    }
}

private struct ItemRow: View {
    let item: PetalItem
    var body: some View {
        HStack {
            switch item.iconKind {
            case .image(let img):
                Image(nsImage: img).resizable().frame(width: 22, height: 22)
            case .symbol(let name):
                Image(systemName: name)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                Text(item.actionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppRow: View {
    let app: AppItem
    var body: some View {
        HStack {
            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
            Text(app.name)
        }
    }
}

private struct ContentUnavailablePlaceholder: View {
    let text: String
    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            Spacer()
        }
    }
}

// MARK: - Login item

/// Thin wrapper over SMAppService for "launch at login".
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("FlowerHUD: login item change failed: \(error.localizedDescription)")
        }
    }
}
