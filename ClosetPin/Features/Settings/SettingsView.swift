import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    @State private var defaultScenario: OutfitScenario = .dailyOffice
    @State private var preferredFormality = 3
    @State private var workplaceDressCode = ""
    @State private var hasLoadedPreference = false
    @State private var currentPreferenceID: UUID?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("settings.preferences.section")) {
                    Picker(L10n.text("settings.default_scenario.label"), selection: $defaultScenario) {
                        ForEach(OutfitScenario.allCases) { scenario in
                            Text(scenario.displayName).tag(scenario)
                        }
                    }

                    Stepper(
                        L10n.string("settings.preferred_formality.format", arguments: preferredFormality),
                        value: $preferredFormality,
                        in: 1...5
                    )

                    TextField(
                        L10n.text("settings.workplace_dress_code.placeholder"),
                        text: $workplaceDressCode,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }

                Section(L10n.text("settings.privacy.section")) {
                    SettingsNoteRow(
                        systemImage: "lock.shield",
                        title: L10n.text("settings.privacy.ai.title"),
                        bodyText: L10n.text("settings.privacy.ai.body")
                    )

                    SettingsNoteRow(
                        systemImage: "iphone",
                        title: L10n.text("settings.privacy.local.title"),
                        bodyText: L10n.text("settings.privacy.local.body")
                    )
                }
            }
            .navigationTitle(L10n.text("settings.title"))
            .onAppear(perform: loadPreferenceIfNeeded)
            .onChange(of: defaultScenario) { _, _ in savePreference() }
            .onChange(of: preferredFormality) { _, _ in savePreference() }
            .onChange(of: workplaceDressCode) { _, _ in savePreference() }
            .alert(L10n.text("settings.save_error_title"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(L10n.text("common.ok"), role: .cancel) {}
            } message: {
                Text(saveError ?? L10n.text("common.try_again"))
            }
        }
    }

    private func loadPreferenceIfNeeded() {
        guard !hasLoadedPreference else { return }
        let preference = currentPreference ?? createPreference()

        currentPreferenceID = preference.id
        defaultScenario = preference.defaultScenario
        preferredFormality = preference.preferredFormality
        workplaceDressCode = preference.workplaceDressCode
        hasLoadedPreference = true
    }

    private func createPreference() -> UserPreference {
        let preference = UserPreference()
        currentPreferenceID = preference.id
        modelContext.insert(preference)
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
        return preference
    }

    private func savePreference() {
        guard hasLoadedPreference else { return }
        let preference = currentPreference ?? createPreference()

        preference.applySettings(
            defaultScenario: defaultScenario,
            preferredFormality: preferredFormality,
            workplaceDressCode: workplaceDressCode
        )

        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var currentPreference: UserPreference? {
        if let currentPreferenceID,
           let matchingPreference = preferences.first(where: { $0.id == currentPreferenceID }) {
            return matchingPreference
        }

        return preferences.first
    }
}

private struct SettingsNoteRow: View {
    let systemImage: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(DesignSystem.accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(bodyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
