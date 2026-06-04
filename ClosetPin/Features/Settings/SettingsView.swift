import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    @State private var defaultScenario: OutfitScenario = .dailyOffice
    @State private var preferredFormality = 3
    @State private var workplaceDressCode = ""
    @State private var cloudPhotoRecognitionEnabled = false
    @State private var tomorrowWeatherEnabled = false
    @State private var tomorrowWeatherLocationName = ""
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
                                title: L10n.text("settings.style_preferences.section"),
                                subtitle: L10n.text("settings.style_preferences.subtitle")
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
                                    arguments: defaultScenario.displayName, preferredFormalityLabel(preferredFormality)
                                )
                            )
                            .accessibilityIdentifier("settingsAppliedPreferenceNote")

                            Divider()
                                .padding(.vertical, 6)

                            SettingsSectionHeader(
                                title: L10n.text("settings.weather.section"),
                                subtitle: L10n.text("settings.weather.subtitle")
                            )

                            TomorrowWeatherSettingsCard(
                                isEnabled: $tomorrowWeatherEnabled,
                                locationName: $tomorrowWeatherLocationName
                            )
                        }
                    }

                    LuxurySurfaceCard(isElevated: tomorrowWeatherEnabled) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SettingsSectionHeader(
                                title: L10n.text("settings.ai_privacy.section"),
                                subtitle: L10n.text("settings.ai_privacy.subtitle")
                            )

                            AIUsageOverviewCard()

                            SettingsNoteRow(
                                systemImage: "camera.badge.ellipsis",
                                title: L10n.text("settings.ai_privacy.photo_title"),
                                bodyText: L10n.text("settings.ai_privacy.photo_body"),
                                isCompact: true
                            )

                            AIAssistStatusCard(
                                cloudPhotoRecognitionEnabled: cloudPhotoRecognitionEnabled,
                                tomorrowWeatherEnabled: tomorrowWeatherEnabled,
                                tomorrowWeatherLocationName: tomorrowWeatherLocationName
                            )

                            Divider()

                            SettingsSubsectionHeader(
                                systemImage: "photo.badge.plus",
                                title: L10n.text("settings.privacy.cloud_photo_recognition.title"),
                                bodyText: ""
                            )

                            CloudPhotoRecognitionToggle(isOn: $cloudPhotoRecognitionEnabled)

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                SettingsNoteRow(
                                    systemImage: "person.crop.circle.badge.questionmark",
                                    title: L10n.text("settings.privacy.ai.title"),
                                    bodyText: L10n.text("settings.privacy.ai.body"),
                                    isCompact: true
                                )

                                SettingsNoteRow(
                                    systemImage: "lock.shield",
                                    title: L10n.text("settings.privacy.local.title"),
                                    bodyText: L10n.text("settings.privacy.local.body"),
                                    isCompact: true
                                )
                            }
                        }
                    }

                    LuxurySurfaceCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SettingsSectionHeader(
                                title: L10n.text("settings.language.section"),
                                subtitle: ""
                            )

                            SettingsNoteRow(
                                systemImage: "globe",
                                title: L10n.text("settings.language.title"),
                                bodyText: systemLanguageName(),
                                isCompact: true
                            )

                            Divider()
                                .padding(.vertical, 2)

                            SettingsSectionHeader(
                                title: L10n.text("settings.about.section"),
                                subtitle: ""
                            )

                            SettingsNoteRow(
                                systemImage: "info.circle",
                                title: L10n.text("settings.about.title"),
                                bodyText: L10n.string("settings.about.body.format", arguments: appVersionLabel()),
                                isCompact: true
                            )
                        }
                    }

                }
                .padding(18)
                .safeAreaPadding(.bottom, DesignSystem.Spacing.tabBarClearance + DesignSystem.Spacing.md)
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadPreferenceIfNeeded)
            .onChange(of: defaultScenario) { _, _ in savePreference() }
            .onChange(of: preferredFormality) { _, _ in savePreference() }
            .onChange(of: workplaceDressCode) { _, _ in savePreference() }
            .onChange(of: cloudPhotoRecognitionEnabled) { _, _ in savePreference() }
            .onChange(of: tomorrowWeatherEnabled) { _, _ in savePreference() }
            .onChange(of: tomorrowWeatherLocationName) { _, _ in savePreference() }
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

    private func appVersionLabel() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? L10n.text("settings.about.version_unknown")
    }

    private func systemLanguageName() -> String {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        return Locale.current.localizedString(forIdentifier: preferredIdentifier) ?? preferredIdentifier
    }

    private func loadPreferenceIfNeeded() {
        guard !hasLoadedPreference else { return }
        let preference = currentPreference ?? createPreference()

        currentPreferenceID = preference.id
        defaultScenario = preference.defaultScenario
        preferredFormality = preference.preferredFormality
        workplaceDressCode = preference.workplaceDressCode
        cloudPhotoRecognitionEnabled = preference.cloudPhotoRecognitionEnabled
        tomorrowWeatherEnabled = preference.tomorrowWeatherEnabled
        tomorrowWeatherLocationName = preference.tomorrowWeatherLocationName
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
            cloudPhotoRecognitionEnabled: cloudPhotoRecognitionEnabled,
            tomorrowWeatherEnabled: tomorrowWeatherEnabled,
            tomorrowWeatherLocationName: tomorrowWeatherLocationName
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

            Text(L10n.string(
                "settings.summary.title.format",
                arguments: scenario.displayName,
                preferredFormalityLabel(formality)
            ))
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

            if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsSubsectionHeader: View {
    let systemImage: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignSystem.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                if !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(bodyText)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(DesignSystem.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
    }
}

private struct AIAssistStatusCard: View {
    let cloudPhotoRecognitionEnabled: Bool
    let tomorrowWeatherEnabled: Bool
    let tomorrowWeatherLocationName: String

    private var tomorrowWeatherStatus: String {
        guard tomorrowWeatherEnabled else {
            return L10n.text("settings.ai_status.weather.status.optional")
        }
        let trimmedLocation = tomorrowWeatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLocation.isEmpty
            ? L10n.text("settings.ai_status.weather.status.needs_city")
            : L10n.text("settings.ai_status.weather.status.on")
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            AIAssistStatusRow(
                systemImage: "camera.metering.center.weighted",
                title: L10n.text("settings.ai_status.photo.title"),
                status: cloudPhotoRecognitionEnabled
                    ? L10n.text("settings.ai_status.photo.status.cloud")
                    : L10n.text("settings.ai_status.photo.status.local"),
                detail: L10n.text("settings.ai_status.photo.detail")
            )

            AIAssistStatusRow(
                systemImage: "sparkles",
                title: L10n.text("settings.ai_status.ranking.title"),
                status: L10n.text("settings.ai_status.ranking.status"),
                detail: L10n.text("settings.ai_status.ranking.detail")
            )

            AIAssistStatusRow(
                systemImage: "cloud.sun",
                title: L10n.text("settings.ai_status.weather.title"),
                status: tomorrowWeatherStatus,
                detail: L10n.text("settings.ai_status.weather.detail")
            )
        }
        .accessibilityIdentifier("settingsAIStatusCard")
    }
}

private struct AIUsageOverviewCard: View {
    private let rows: [(icon: String, titleKey: String, bodyKey: String)] = [
        ("camera.badge.ellipsis", "settings.ai_overview.photo.title", "settings.ai_overview.photo.body"),
        ("sparkles", "settings.ai_overview.today.title", "settings.ai_overview.today.body"),
        ("cloud.sun", "settings.ai_overview.weather.title", "settings.ai_overview.weather.body")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(L10n.text("settings.ai_overview.title"), systemImage: "wand.and.sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)

            ForEach(rows, id: \.titleKey) { row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignSystem.accent)
                        .frame(width: 22, height: 22)
                        .background(DesignSystem.accent.opacity(0.09))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text(row.titleKey))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.ink)

                        Text(L10n.text(row.bodyKey))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.48), lineWidth: 1)
        }
        .accessibilityIdentifier("settingsAIUsageOverviewCard")
    }
}

private struct AIAssistStatusRow: View {
    let systemImage: String
    let title: String
    let status: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignSystem.accent)
                .frame(width: 24, height: 24)
                .background(DesignSystem.accent.opacity(0.09))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(DesignSystem.accent.opacity(0.09))
                        .clipShape(Capsule(style: .continuous))
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
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
    private let levels = [1, 2, 3, 4, 5]
    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: .infinity), spacing: DesignSystem.Spacing.xs),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.string("settings.preferred_formality.format", arguments: preferredFormalityLabel(value)))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.xs) {
                ForEach(levels, id: \.self) { option in
                    let isSelected = value == option

                    Button {
                        value = option
                    } label: {
                        Text(preferredFormalityLabel(option))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? .white : DesignSystem.ink)
                            .background(isSelected ? DesignSystem.accent : DesignSystem.paper)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(isSelected ? DesignSystem.accent.opacity(0.2) : DesignSystem.border.opacity(0.75), lineWidth: 1)
                    }
                    .accessibilityIdentifier("formalityLevel_\(option)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.bottom, 2)
        }
    }
}

private func preferredFormalityLabel(_ value: Int) -> String {
    switch clampedFormalityLevel(value) {
    case 1:
        L10n.text("closet.formality.level_1")
    case 2:
        L10n.text("closet.formality.level_2")
    case 3:
        L10n.text("closet.formality.level_3")
    case 4:
        L10n.text("closet.formality.level_4")
    default:
        L10n.text("closet.formality.level_5")
    }
}

private func clampedFormalityLevel(_ value: Int) -> Int {
    max(1, min(5, value))
}

private struct TomorrowWeatherSettingsCard: View {
    @Binding var isEnabled: Bool
    @Binding var locationName: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Toggle(isOn: $isEnabled.animation(.snappy(duration: 0.22))) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("settings.weather.enabled.title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Text(L10n.text("settings.weather.enabled.body"))
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(DesignSystem.accent)
            .accessibilityIdentifier("tomorrowWeatherToggle")

            if isEnabled {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "location.magnifyingglass")
                            .foregroundStyle(DesignSystem.accent)

                        TextField(L10n.text("settings.weather.location.placeholder"), text: $locationName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("tomorrowWeatherLocationField")
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, 12)
                    .background(DesignSystem.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                            .stroke(DesignSystem.accent.opacity(0.28), lineWidth: 1)
                    }

                    Text(L10n.text("settings.weather.location.helper"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if !trimmedLocationName.isEmpty {
                        Label(L10n.string("settings.weather.ready.format", arguments: trimmedLocationName), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.accent)
                            .accessibilityIdentifier("tomorrowWeatherReadyNote")
                    }
                }
            } else {
                SettingsNoteRow(
                    systemImage: "location.slash",
                    title: L10n.text("settings.weather.disabled.title"),
                    bodyText: L10n.text("settings.weather.disabled.helper")
                )
            }

        }
    }

    private var trimmedLocationName: String {
        locationName.trimmingCharacters(in: .whitespacesAndNewlines)
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
    var isCompact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 10 : 12) {
            Image(systemName: systemImage)
                .font(isCompact ? .callout : .title3)
                .foregroundStyle(DesignSystem.accent)
                .frame(width: isCompact ? 22 : 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(isCompact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(bodyText)
                    .font(isCompact ? .caption : .footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, isCompact ? 2 : 4)
    }
}
