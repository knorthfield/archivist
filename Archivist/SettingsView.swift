import SwiftUI

struct SettingsView: View {
    let model: HistoryModel

    @AppStorage(Settings.keepHistory) private var keepHistory = HistoryRetention.month
    @AppStorage(Settings.ignoreTransientContent) private var ignoresTransientContent = true
    @AppStorage(Settings.ignoreConfidentialContent) private var ignoresConfidentialContent = true

    @State private var opensAtLogin = LoginItem.isEnabled
    @State private var ignoredApps = UserDefaults.standard.stringArray(forKey: Settings.ignoredApps) ?? []
    @State private var isConfirmingClear = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at Login", isOn: Binding(
                    get: { opensAtLogin },
                    set: { LoginItem.set($0); opensAtLogin = LoginItem.isEnabled }))
            }

            Section {
                Picker("Keep History", selection: $keepHistory) {
                    ForEach(HistoryRetention.allCases, id: \.self) { Text($0.name) }
                }
                .onChange(of: keepHistory) { model.deleteOldItems() }
                Button("Clear History…") { isConfirmingClear = true }
                    .confirmationDialog("Delete all the items that are not in a pinboard?", isPresented: $isConfirmingClear) {
                        Button("Clear History", role: .destructive) { model.clearHistory() }
                    } message: {
                        Text("You cannot undo this.")
                    }
            } header: {
                Text("History")
            } footer: {
                Text("Items in a pinboard stay until you delete them.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(ignoredApps, id: \.self) { bundleID in
                    HStack {
                        Text(Self.appName(of: bundleID))
                        Spacer()
                        Button("Remove", systemImage: "minus.circle") { setIgnoredApps(ignoredApps.filter { $0 != bundleID }) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add App…", action: addIgnoredApp)
            } header: {
                Text("Ignored Apps")
            } footer: {
                Text("Archivist does not save a copy that you make while one of these apps is at the front.")
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle(isOn: $ignoresConfidentialContent) {
                    Text("Ignore Confidential Content")
                    Text("Do not save passwords and other data that an app marks as confidential.")
                }
                Toggle(isOn: $ignoresTransientContent) {
                    Text("Ignore Transient Content")
                    Text("Do not save temporary data that other apps put on the clipboard.")
                }
            }

            Section("Shortcuts") {
                LabeledContent("Show or hide Archivist", value: "⇧⌘V")
                LabeledContent("Paste / paste as plain text", value: "↩ / ⇧↩")
                LabeledContent("Quick Paste / as plain text", value: "⌘1…9 / ⇧⌘1…9")
                LabeledContent("Search", value: "Type")
                LabeledContent("Quick Look", value: "Space")
                LabeledContent("Copy / open", value: "⌘C / ⌘O")
                LabeledContent("Edit / rename / new item", value: "⌘E / ⌘R / ⌘N")
                LabeledContent("Delete / undo", value: "⌫ / ⌘Z")
                LabeledContent("Previous / next pinboard", value: "⌘← / ⌘→")
                LabeledContent("New pinboard", value: "⇧⌘N")
                LabeledContent("Pause or resume", value: "⌘T")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
    }

    private func setIgnoredApps(_ apps: [String]) {
        ignoredApps = apps
        UserDefaults.standard.set(apps, forKey: Settings.ignoredApps)
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier, !ignoredApps.contains(bundleID) else { return }
        setIgnoredApps(ignoredApps + [bundleID])
    }

    private static func appName(of bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }
}
