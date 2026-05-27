import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    @State private var defaultScenario: OutfitScenario = .dailyOffice
    @State private var preferredFormality = 3
    @State private var workplaceDressCode = ""
    @State private var cloudPhotoRecognitionEnabled = false
    @State private var hasLoadedPreference = false
    @State private var currentPreferenceID: UUID?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    SettingsSummaryCard(scenario: defaultScenario, formality: preferredFormality)

                    LuxurySurfaceCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            SettingsSectionHeader(
                                title: L10n.text("settings.preferences.section"),
                                subtitle: L10n.text("settings.preferences.subtitle")
                            )

                            ScenarioSelectionRow(selection: $defaultScenario)

                            FormalityControl(value: $preferredFormality)

                            TextField(
                                L10n.text("settings.workplace_dress_code.placeholder"),
                                text: $workplaceDressCode,
                                axis: .vertical
                            )
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("workplaceDressCodeField")

                            Text(L10n.text("settings.workplace_dress_code.helper"))
                                .font(.caption)
                                .foregroundStyle(DesignSystem.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)

                            SettingsNoteRow(
                                systemImage: "checkmark.seal.fill",
                                title: L10n.text("settings.preferences.applied.title"),
                                bodyText: L10n.string(
                                    "settings.preferences.applied.body.format",
                                    arguments: defaultScenario.displayName, preferredFormality
                                )
                            )
                            .accessibilityIdentifier("settingsAppliedPreferenceNote")
                        }
                    }

                    LuxurySurfaceCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            SettingsSectionHeader(
                                title: L10n.text("settings.privacy.section"),
                                subtitle: L10n.text("settings.privacy.subtitle")
                            )

                            Divider()

                            CloudPhotoRecognitionToggle(isOn: $cloudPhotoRecognitionEnabled)

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
                }
                .padding(18)
                .padding(.bottom, DesignSystem.Spacing.tabBarClearance)
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadPreferenceIfNeeded)
            .onChange(of: defaultScenario) { _, _ in savePreference() }
            .onChange(of: preferredFormality) { _, _ in savePreference() }
            .onChange(of: workplaceDressCode) { _, _ in savePreference() }
            .onChange(of: cloudPhotoRecognitionEnabled) { _, _ in savePreference() }
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
        cloudPhotoRecognitionEnabled = preference.cloudPhotoRecognitionEnabled
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
            workplaceDressCode: workplaceDressCode,
            cloudPhotoRecognitionEnabled: cloudPhotoRecognitionEnabled
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

private struct SettingsSummaryCard: View {
    let scenario: OutfitScenario
    let formality: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label(L10n.text("settings.summary.kicker"), systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(L10n.string("settings.summary.title.format", arguments: scenario.displayName, formality))
                .font(DesignSystem.editorialDisplayFont(size: 30))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("settings.summary.body"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [DesignSystem.accent, DesignSystem.wine],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(DesignSystem.premiumGold.opacity(0.32))
                .frame(width: 128, height: 128)
                .offset(x: 44, y: -52)
        }
        .shadow(color: DesignSystem.editorialShadow.opacity(0.75), radius: 24, x: 0, y: 16)
        .accessibilityIdentifier("settingsSummaryCard")
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(DesignSystem.editorialSectionFont(size: 22))
                .foregroundStyle(DesignSystem.ink)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ScenarioSelectionRow: View {
    @Binding var selection: OutfitScenario

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("settings.default_scenario.label"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), GridItem(.flexible(), spacing: DesignSystem.Spacing.sm)], spacing: DesignSystem.Spacing.sm) {
                ForEach(OutfitScenario.allCases) { scenario in
                    PreferenceOptionButton(
                        title: scenario.displayName,
                        isSelected: selection == scenario,
                        accessibilityIdentifier: "defaultScenarioOption_\(scenario.rawValue)"
                    ) {
                        selection = scenario
                    }
                }
            }
        }
    }
}

private struct PreferenceOptionButton: View {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                }

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(isSelected ? .white : DesignSystem.ink)
            .background(isSelected ? DesignSystem.accent : DesignSystem.paper)
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isSelected ? DesignSystem.accent.opacity(0.18) : DesignSystem.border.opacity(0.75), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct FormalityControl: View {
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.string("settings.preferred_formality.format", arguments: value))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            HStack(spacing: DesignSystem.Spacing.md) {
                SettingsRoundButton(
                    systemImage: "minus",
                    accessibilityLabel: L10n.text("settings.formality.decrease"),
                    accessibilityIdentifier: "settingsFormalityDecreaseButton",
                    isDisabled: value <= 1
                ) {
                    value = max(1, value - 1)
                }

                VStack(spacing: 4) {
                    Text("\(value)")
                        .font(DesignSystem.editorialDisplayFont(size: 34))
                        .foregroundStyle(DesignSystem.ink)

                    Text(L10n.text("settings.formality.scale"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignSystem.surface.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))

                SettingsRoundButton(
                    systemImage: "plus",
                    accessibilityLabel: L10n.text("settings.formality.increase"),
                    accessibilityIdentifier: "settingsFormalityIncreaseButton",
                    isDisabled: value >= 5
                ) {
                    value = min(5, value + 1)
                }
            }
        }
    }
}

private struct SettingsRoundButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 44, height: 44)
                .foregroundStyle(isDisabled ? DesignSystem.secondaryInk.opacity(0.45) : .white)
                .background(isDisabled ? DesignSystem.border.opacity(0.55) : DesignSystem.accent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CloudPhotoRecognitionToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("settings.privacy.cloud_photo_recognition.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(L10n.text("settings.privacy.cloud_photo_recognition.body"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(DesignSystem.accent)
        .accessibilityIdentifier("cloudPhotoRecognitionToggle")
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
