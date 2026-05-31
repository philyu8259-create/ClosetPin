import Foundation
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    @State private var scenario: OutfitScenario = .dailyOffice
    @State private var season: SeasonTag = SeasonResolver.currentSeason()
    @State private var pendingActionIDs: Set<String> = []
    @State private var confirmation: TodayConfirmation?
    @State private var saveError: String?
    @State private var lastAppliedPreferenceScenario: OutfitScenario?
    @State private var forecastLocationKey = ""
    @State private var tomorrowWeatherSnapshot: TomorrowWeatherSnapshot?
    @State private var tomorrowWeatherIsLoading = false
    @State private var tomorrowWeatherMessage: String?

    let onOpenLooks: (() -> Void)?
    let onOpenCloset: (() -> Void)?

    private let engine = RecommendationEngine()
    private let feedbackRecorder = TodayFeedbackRecorder()
    private let tomorrowWeatherProvider: any TomorrowWeatherProviding

    init(
        onOpenLooks: (() -> Void)? = nil,
        onOpenCloset: (() -> Void)? = nil,
        tomorrowWeatherProvider: any TomorrowWeatherProviding = WeatherKitTomorrowWeatherProvider()
    ) {
        self.onOpenLooks = onOpenLooks
        self.onOpenCloset = onOpenCloset
        self.tomorrowWeatherProvider = tomorrowWeatherProvider
    }

    private var candidates: [OutfitCandidate] {
        engine.recommend(
            input: RecommendationInput(
                scenario: scenario,
                season: season,
                maximumResults: 3,
                preferredFormality: currentPreference?.preferredFormality
            ),
            items: clothingItems,
            feedback: feedback
        )
    }

    private var tomorrowCandidate: OutfitCandidate? {
        guard let context = activeTomorrowWeatherContext else { return nil }

        let tomorrowRecommendation = engine.recommend(
            input: RecommendationInput(
                scenario: scenario,
                season: season,
                tomorrow: TomorrowRecommendationInput(weatherContext: context),
                maximumResults: 1,
                preferredFormality: currentPreference?.preferredFormality
            ),
            items: clothingItems,
            feedback: feedback
        ).first
        if let tomorrowRecommendation {
            return tomorrowRecommendation
        }

        return candidates.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.editorial) {
                    contextStrip
                    tomorrowPrepSection
                    editorialHero

                    if candidates.count > 1 {
                        alternativesSection
                    }
                }
                .padding(18)
                .padding(.bottom, DesignSystem.Spacing.tabBarClearance)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("today.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: applyPreferenceDefaultsIfNeeded)
            .onChange(of: currentPreference?.updatedAt) { _, _ in
                applyPreferenceDefaultsIfNeeded()
            }
            .task(id: tomorrowWeatherRequestKey) {
                await refreshTomorrowWeatherIfNeeded()
            }
            .safeAreaInset(edge: .bottom) {
                if let confirmation {
                    ConfirmationBanner(
                        confirmation: confirmation,
                        onOpenLooks: onOpenLooks
                    )
                        .padding(.horizontal, 18)
                        .padding(.bottom, DesignSystem.Spacing.tabBarClearance + 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(L10n.text("today.feedback_error_title"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(L10n.text("common.ok"), role: .cancel) {}
            } message: {
                Text(saveError ?? L10n.text("common.try_again"))
            }
        }
    }

    private var editorialHero: some View {
        Group {
            if let heroCandidate = candidates.first {
                TodayEditorialHero(
                    candidate: heroCandidate,
                    title: recommendationName,
                    explanation: TodayRecommendationExplanation.text(for: heroCandidate, scenario: scenario),
                    pendingActionIDs: pendingActionIDs,
                    onAction: { action in
                        record(action, for: heroCandidate)
                    }
                )
            } else {
                MissingRecommendationView(message: missingRecommendationMessage, onOpenCloset: onOpenCloset)
            }
        }
    }

    private var contextStrip: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("today.context.title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            Text(L10n.text("today.ai_assist.body"))
                .font(.caption)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            TodayDecisionGuideCard()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(OutfitScenario.allCases) { scenario in
                        ContextChip(title: scenario.displayName, value: scenario, selection: $scenario)
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityIdentifier("todayScenarioPicker")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(SeasonTag.allCases) { season in
                        ContextChip(title: season.displayName, value: season, selection: $season)
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityIdentifier("todaySeasonPicker")

            Text(L10n.text("today.season.auto_note"))
                .font(.caption2)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            let alternatives = Array(candidates.dropFirst().enumerated())
            if !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text(L10n.text("today.alternatives.title"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    ForEach(alternatives, id: \.element.id) { offset, candidate in
                        let index = offset + 1
                        OutfitCompactCard(
                            index: index,
                            label: alternativeLabel(for: index),
                            candidate: candidate,
                            explanation: TodayRecommendationExplanation.text(for: candidate, scenario: scenario),
                            pendingActionIDs: pendingActionIDs,
                            onAction: { action in
                                record(action, for: candidate)
                            }
                        )
                    }
                }
            }
        }
    }

    private var tomorrowPrepSection: some View {
        Group {
            if let context = activeTomorrowWeatherContext {
                TomorrowPrepCard(
                    weatherSummary: TomorrowWeatherPreview.weatherSummary(for: context),
                    recommendationName: tomorrowCandidate.map { _ in recommendationName },
                    recommendationReason: tomorrowCandidate.map { TodayRecommendationExplanation.text(for: $0, scenario: scenario) },
                    tips: TomorrowWeatherPreview.preparationTips(for: context),
                    attributionName: tomorrowWeatherSnapshot?.attributionName,
                    attributionURL: tomorrowWeatherSnapshot?.attributionURL
                )
            } else if shouldShowTomorrowWeatherStatus {
                TomorrowWeatherStatusCard(
                    isLoading: tomorrowWeatherIsLoading,
                    locationName: currentPreference?.tomorrowWeatherLocationName ?? "",
                    message: tomorrowWeatherMessage ?? L10n.text("today.tomorrow.weather_missing_location")
                )
            }
        }
    }

    private var activeTomorrowWeatherContext: TomorrowWeatherContext? {
        tomorrowWeatherSnapshot?.context ?? TomorrowWeatherPreview.context
    }

    private var shouldShowTomorrowWeatherStatus: Bool {
        currentPreference?.tomorrowWeatherEnabled == true
    }

    private var recommendationName: String {
        switch scenario {
        case .dailyOffice:
            L10n.text("today.best.name.daily_office")
        case .importantMeeting:
            L10n.text("today.best.name.important_meeting")
        case .weekendCasual:
            L10n.text("today.best.name.weekend_casual")
        case .banquet:
            L10n.text("today.best.name.banquet")
        }
    }

    private var currentPreference: UserPreference? {
        preferences.first
    }

    private var tomorrowWeatherRequestKey: String {
        guard let currentPreference else { return "none" }
        return [
            currentPreference.tomorrowWeatherEnabled ? "enabled" : "disabled",
            currentPreference.tomorrowWeatherLocationName
        ].joined(separator: ":")
    }

    private func applyPreferenceDefaultsIfNeeded() {
        let preferredScenario = currentPreference?.defaultScenario ?? .dailyOffice
        guard lastAppliedPreferenceScenario == nil || scenario == lastAppliedPreferenceScenario else {
            return
        }

        scenario = preferredScenario
        lastAppliedPreferenceScenario = preferredScenario
    }

    @MainActor
    private func refreshTomorrowWeatherIfNeeded() async {
        guard let preference = currentPreference, preference.tomorrowWeatherEnabled else {
            tomorrowWeatherSnapshot = nil
            tomorrowWeatherIsLoading = false
            tomorrowWeatherMessage = nil
            forecastLocationKey = ""
            return
        }

        guard preference.canRequestTomorrowWeather else {
            tomorrowWeatherSnapshot = nil
            tomorrowWeatherIsLoading = false
            tomorrowWeatherMessage = L10n.text("today.tomorrow.weather_missing_location")
            forecastLocationKey = ""
            return
        }

        let locationName = preference.tomorrowWeatherLocationName
        guard forecastLocationKey != locationName || tomorrowWeatherSnapshot == nil else { return }

        forecastLocationKey = locationName
        tomorrowWeatherSnapshot = nil
        tomorrowWeatherMessage = nil
        tomorrowWeatherIsLoading = true

        do {
            let snapshot = try await tomorrowWeatherProvider.tomorrowWeather(for: locationName, referenceDate: Date())
            tomorrowWeatherSnapshot = snapshot
            tomorrowWeatherMessage = nil
        } catch {
            tomorrowWeatherSnapshot = nil
            tomorrowWeatherMessage = L10n.text("today.tomorrow.weather_unavailable")
        }

        tomorrowWeatherIsLoading = false
    }

    private var missingRecommendationMessage: String {
        let requiredTypes = requiredTypes(for: scenario)
        let threshold = requiredFormality(for: scenario)

        for type in requiredTypes {
            let availableSeasonItems = clothingItems.filter { item in
                item.resolvedType == type
                    && item.resolvedStatus == .available
                    && item.seasons.contains(season)
            }

            if availableSeasonItems.isEmpty {
                return L10n.string(
                    "today.missing.add_one.format",
                    arguments: type.missingItemPhrase, scenario.shortName
                )
            }

            if availableSeasonItems.allSatisfy({ $0.formalityLevel < threshold }) {
                return L10n.string(
                    "today.missing.add_formal.format",
                    arguments: type.missingItemPhrase, scenario.shortName
                )
            }
        }

        return L10n.text("today.missing.available_or_season")
    }

    private func requiredTypes(for scenario: OutfitScenario) -> [ClothingType] {
        switch scenario {
        case .importantMeeting:
            [.top, .bottom, .shoes, .blazer]
        case .dailyOffice, .weekendCasual, .banquet:
            [.top, .bottom, .shoes]
        }
    }

    private func requiredFormality(for scenario: OutfitScenario) -> Int {
        switch scenario {
        case .weekendCasual:
            1
        case .dailyOffice:
            2
        case .importantMeeting, .banquet:
            4
        }
    }

    private func alternativeLabel(for index: Int) -> String {
        index == 1 ? L10n.text("today.alternative.more_formal") : L10n.text("today.alternative.more_relaxed")
    }

    private func record(_ action: TodayFeedbackAction, for candidate: OutfitCandidate) {
        let actionID = "\(candidate.id):\(action.feedbackType.rawValue)"
        guard !pendingActionIDs.contains(actionID) else { return }

        pendingActionIDs.insert(actionID)
        defer { pendingActionIDs.remove(actionID) }

        do {
            let result = try feedbackRecorder.record(
                action.feedbackType,
                candidate: candidate,
                scenario: scenario,
                season: season,
                explanation: TodayRecommendationExplanation.text(for: candidate, scenario: scenario),
                in: modelContext
            )

            withAnimation(.snappy) {
                confirmation = TodayConfirmation(
                    message: action.confirmation(for: action.feedbackType, outcome: result.outcome),
                    showsLookbookAction: action.showsLookbookAction
                )
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

enum TomorrowWeatherPreview {
    static let environmentKey = "CLOSETPIN_TOMORROW_WEATHER_PREVIEW"
    static let launchArgumentKey = "-\(environmentKey)"
    static let inlineLaunchArgumentPrefix = "--closetpin-tomorrow-weather="

    static var context: TomorrowWeatherContext? {
        guard let rawContext = ProcessInfo.processInfo.environment[environmentKey]
            ?? UserDefaults.standard.string(forKey: environmentKey)
            ?? rawContextFromArguments else {
            return nil
        }

        return context(from: rawContext)
    }

    static func context(from rawContext: String) -> TomorrowWeatherContext? {
        if let presetContext = presetContext(for: rawContext) {
            return presetContext
        }

        guard let payloadData = rawContext.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(TomorrowWeatherPreviewPayload.self, from: payloadData) else {
            return nil
        }

        return payload.weatherContext
    }

    static func weatherSummary(for context: TomorrowWeatherContext) -> String {
        L10n.string(
            "today.tomorrow.weather_summary.format",
            arguments: context.condition.localizedName,
            context.minTemperatureCelsius,
            context.maxTemperatureCelsius,
            context.precipitationProbability,
            context.windSpeedKph
        )
    }

    static func preparationTips(for context: TomorrowWeatherContext) -> [String] {
        var tips: [String] = []

        if context.isCold {
            tips.append(L10n.text("today.tomorrow.prep.tip.outerwear"))
        }

        if context.isRainLikely {
            tips.append(L10n.text("today.tomorrow.prep.tip.rain_shoes"))
        }

        if context.isHot {
            tips.append(L10n.text("today.tomorrow.prep.tip.no_blazer"))
        } else if !context.isCold && !context.isRainLikely {
            tips.append(L10n.text("today.tomorrow.prep.tip.light_layer"))
        }

        if context.isWindy {
            tips.append(L10n.text("today.tomorrow.prep.tip.wind"))
        }

        if tips.count < 2 {
            tips.append(L10n.text("today.tomorrow.prep.tip.neutral"))
        }

        return Array(tips.prefix(3))
    }

    private static func presetContext(for rawContext: String) -> TomorrowWeatherContext? {
        switch rawContext
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_") {
        case "rain", "rainy_commute":
            TomorrowWeatherContext(
                condition: .rain,
                minTemperatureCelsius: 11,
                maxTemperatureCelsius: 18,
                precipitationProbability: 70,
                windSpeedKph: 22
            )
        case "cold", "cold_morning":
            TomorrowWeatherContext(
                condition: .cloudy,
                minTemperatureCelsius: 3,
                maxTemperatureCelsius: 10,
                precipitationProbability: 20,
                windSpeedKph: 18
            )
        case "hot", "hot_day":
            TomorrowWeatherContext(
                condition: .clear,
                minTemperatureCelsius: 27,
                maxTemperatureCelsius: 34,
                precipitationProbability: 10,
                windSpeedKph: 12
            )
        default:
            nil
        }
    }

    private static var rawContextFromArguments: String? {
        if let inlineArgument = CommandLine.arguments.first(where: { $0.hasPrefix(inlineLaunchArgumentPrefix) }) {
            return String(inlineArgument.dropFirst(inlineLaunchArgumentPrefix.count))
        }

        guard let index = CommandLine.arguments.firstIndex(of: launchArgumentKey),
              CommandLine.arguments.indices.contains(index + 1) else {
            return nil
        }

        return CommandLine.arguments[index + 1]
    }
}

private struct TomorrowWeatherPreviewPayload: Decodable {
    let condition: TomorrowWeatherCondition
    let minTemperatureCelsius: Int
    let maxTemperatureCelsius: Int
    let precipitationProbability: Int
    let windSpeedKph: Int

    var weatherContext: TomorrowWeatherContext {
        TomorrowWeatherContext(
            condition: condition,
            minTemperatureCelsius: minTemperatureCelsius,
            maxTemperatureCelsius: maxTemperatureCelsius,
            precipitationProbability: precipitationProbability,
            windSpeedKph: windSpeedKph
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawCondition = try container.decode(String.self, forKey: .condition)
        condition = TomorrowWeatherCondition(debugValue: rawCondition) ?? .unknown
        minTemperatureCelsius = try container.decode(Int.self, forKey: .minTemperatureCelsius)
        maxTemperatureCelsius = try container.decode(Int.self, forKey: .maxTemperatureCelsius)
        precipitationProbability = try container.decode(Int.self, forKey: .precipitationProbability)
        windSpeedKph = try container.decode(Int.self, forKey: .windSpeedKph)
    }

    enum CodingKeys: String, CodingKey {
        case condition
        case minTemperatureCelsius
        case maxTemperatureCelsius
        case precipitationProbability
        case windSpeedKph
    }
}

private extension TomorrowWeatherCondition {
    var localizedName: String {
        switch self {
        case .clear:
            L10n.text("today.tomorrow.condition.clear")
        case .partlyCloudy:
            L10n.text("today.tomorrow.condition.partly_cloudy")
        case .cloudy:
            L10n.text("today.tomorrow.condition.cloudy")
        case .lightRain:
            L10n.text("today.tomorrow.condition.light_rain")
        case .rain:
            L10n.text("today.tomorrow.condition.rain")
        case .thunderstorms:
            L10n.text("today.tomorrow.condition.thunderstorms")
        case .snow:
            L10n.text("today.tomorrow.condition.snow")
        case .wind:
            L10n.text("today.tomorrow.condition.wind")
        case .unknown:
            L10n.text("today.tomorrow.condition.unknown")
        }
    }
}

private extension TomorrowWeatherCondition {
    init?(debugValue: String) {
        let normalized = debugValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")

        if let exact = TomorrowWeatherCondition(rawValue: normalized) {
            self = exact
            return
        }

        switch normalized {
        case "partly cloudy", "partlycloudy", "partly_cloud", "partly_cloudy", "partlycloud":
            self = .partlyCloudy
        case "light rain", "lightrain", "light_rain", "drizzle":
            self = .lightRain
        case "heavy rain", "rain", "raining":
            self = .rain
        case "storm", "stormy", "thunderstorm", "thunder_storm":
            self = .thunderstorms
        case "windy":
            self = .wind
        case "clear sky", "sun":
            self = .clear
        case "overcast":
            self = .cloudy
        case "snowy":
            self = .snow
        default:
            self = .unknown
            return
        }
    }
}

private struct TodayDecisionGuideCard: View {
    private let steps: [(titleKey: String, bodyKey: String, icon: String)] = [
        ("today.decision.user.title", "today.decision.user.body", "hand.tap.fill"),
        ("today.decision.ai.title", "today.decision.ai.body", "sparkles"),
        ("today.decision.final.title", "today.decision.final.body", "checkmark.seal.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(steps, id: \.titleKey) { step in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: step.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignSystem.premiumGold)
                        .frame(width: 22, height: 22)
                        .background(DesignSystem.premiumGold.opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text(step.titleKey))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.ink)

                        Text(L10n.text(step.bodyKey))
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.paper.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
        }
        .accessibilityIdentifier("todayDecisionGuide")
    }
}

private struct TomorrowPrepCard: View {
    let weatherSummary: String
    let recommendationName: String?
    let recommendationReason: String?
    let tips: [String]
    let attributionName: String?
    let attributionURL: URL?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Label(L10n.text("today.tomorrow.prep.title"), systemImage: "cloud.sun.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.secondaryInk)

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    if let attributionName {
                        Text(L10n.string("today.tomorrow.attribution.format", arguments: attributionName))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .lineLimit(1)
                    }
                }
                .accessibilityIdentifier("tomorrowPrepTitle")

                Text(weatherSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .accessibilityIdentifier("tomorrowPrepWeatherSummary")

                Divider()

                if let recommendationName, let recommendationReason {
                    Text(L10n.string("today.tomorrow.recommendation_name.format", arguments: recommendationName))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)
                        .accessibilityIdentifier("tomorrowPrepRecommendationName")

                    Text(recommendationReason)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("tomorrowPrepRecommendationReason")
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(L10n.text("today.tomorrow.prep.tips_title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.secondaryInk)

                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignSystem.accent)
                                .font(.caption)

                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityIdentifier("tomorrowPrepTip_\(index)")
                    }
                }

                if let attributionURL {
                    Link(L10n.text("today.tomorrow.attribution.link"), destination: attributionURL)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .accessibilityIdentifier("tomorrowPrepWeatherAttributionLink")
                }
            }
        }
        .accessibilityIdentifier("tomorrowPrepCard")
    }
}

private struct TomorrowWeatherStatusCard: View {
    let isLoading: Bool
    let locationName: String
    let message: String

    var body: some View {
        LuxurySurfaceCard {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.accent.opacity(0.12))
                        .frame(width: 42, height: 42)

                    if isLoading {
                        ProgressView()
                            .tint(DesignSystem.accent)
                    } else {
                        Image(systemName: "cloud.sun")
                            .font(.headline)
                            .foregroundStyle(DesignSystem.accent)
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(L10n.text("today.tomorrow.weather_status.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("tomorrowWeatherStatusCard")
    }

    private var statusText: String {
        if isLoading {
            return L10n.string("today.tomorrow.weather_loading.format", arguments: locationName)
        }

        return message
    }
}

private struct TodayEditorialHero: View {
    let candidate: OutfitCandidate
    let title: String
    let explanation: String
    let pendingActionIDs: Set<String>
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            EditorialImageSurface(
                image: coverImage,
                height: 330
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label(L10n.text("today.edit.kicker"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.premiumGold)

                    Text(title)
                        .font(DesignSystem.editorialDisplayFont(size: 42))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(explanation)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Label("\(candidate.score)", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
                    .accessibilityLabel(L10n.string("today.score.accessibility.format", arguments: candidate.score))

                Text(L10n.text("today.best.title"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)
            }

            TodayActionPanel(
                candidate: candidate,
                index: 0,
                pendingActionIDs: pendingActionIDs,
                onAction: onAction
            )

            TodayIncludedItemsSection(items: candidate.items, index: 0)
        }
    }

    private var coverImage: UIImage? {
        candidate.items.compactMap { WardrobePhoto.localImage(for: $0) }.first
    }

}

private struct TodayIncludedItemsSection: View {
    let items: [ClothingItem]
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("today.items.title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)
                .accessibilityIdentifier("todayIncludedItemsTitle_\(index)")

            OutfitVisualBoard(items: items)
                .accessibilityIdentifier("todayOutfitVisualBoard_\(index)")
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }
}

private struct OutfitCompactCard: View {
    let index: Int
    let label: String
    let candidate: OutfitCandidate
    let explanation: String
    let pendingActionIDs: Set<String>
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    Label("\(candidate.score)", systemImage: "gauge.with.dots.needle.50percent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .accessibilityLabel(L10n.string("today.score.accessibility.format", arguments: candidate.score))
                }

                OutfitVisualBoard(items: candidate.items)
                    .accessibilityIdentifier("todayOutfitVisualBoard_\(index)")

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                TodayActionPanel(
                    candidate: candidate,
                    index: index,
                    pendingActionIDs: pendingActionIDs,
                    onAction: onAction
                )
            }
        }
    }
}

private struct TodayActionPanel: View {
    let candidate: OutfitCandidate
    let index: Int
    let pendingActionIDs: Set<String>
    let onAction: (TodayFeedbackAction) -> Void

    private let learningActions: [TodayFeedbackAction] = [.like, .dislike, .skip]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    onAction(.wore)
                } label: {
                    Label(TodayFeedbackAction.wore.title, systemImage: TodayFeedbackAction.wore.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.accent)
                .disabled(isPending(.wore))
                .accessibilityIdentifier("todayFeedback_wore_\(index)")

                Button {
                    onAction(.save)
                } label: {
                    Label(TodayFeedbackAction.save.title, systemImage: TodayFeedbackAction.save.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.accent)
                .disabled(isPending(.save))
                .accessibilityIdentifier("todayFeedback_saved_\(index)")
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(L10n.text("today.feedback.tune_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(learningActions) { action in
                        Button {
                            onAction(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(action.tint)
                        .disabled(isPending(action))
                        .accessibilityIdentifier("todayFeedback_\(action.feedbackType.rawValue)_\(index)")
                    }
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.paper.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.border.opacity(0.52), lineWidth: 1)
            }
        }
    }

    private func isPending(_ action: TodayFeedbackAction) -> Bool {
        pendingActionIDs.contains("\(candidate.id):\(action.feedbackType.rawValue)")
    }
}

private struct MissingRecommendationView: View {
    let message: String
    let onOpenCloset: (() -> Void)?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Label(L10n.text("today.missing.title"), systemImage: "exclamationmark.circle")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ink)

                Text(message)
                    .font(.body)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let onOpenCloset {
                    Button(action: onOpenCloset) {
                        Label(L10n.text("today.missing.open_closet"), systemImage: "square.grid.2x2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(DesignSystem.accent)
                    .accessibilityIdentifier("todayMissingOpenClosetButton")
                }
            }
        }
        .accessibilityIdentifier("todayMissingRecommendation")
    }
}

private struct TodayConfirmation: Equatable {
    let message: String
    let showsLookbookAction: Bool
}

private struct ConfirmationBanner: View {
    let confirmation: TodayConfirmation
    let onOpenLooks: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Label(confirmation.message, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if confirmation.showsLookbookAction, let onOpenLooks {
                Button(action: onOpenLooks) {
                    Text(L10n.text("today.confirmation.view_looks"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignSystem.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white)
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("todayFeedbackViewLooksButton")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.accent)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
    }
}

private enum TodayFeedbackAction: CaseIterable, Identifiable {
    case wore
    case like
    case dislike
    case skip
    case save

    var id: String { feedbackType.rawValue }

    var feedbackType: FeedbackType {
        switch self {
        case .wore:
            .wore
        case .like:
            .liked
        case .dislike:
            .disliked
        case .skip:
            .skipped
        case .save:
            .saved
        }
    }

    var title: String {
        switch self {
        case .wore:
            L10n.text("today.feedback.wore")
        case .like:
            L10n.text("today.feedback.like")
        case .dislike:
            L10n.text("today.feedback.dislike")
        case .skip:
            L10n.text("today.feedback.skip")
        case .save:
            L10n.text("today.feedback.save")
        }
    }

    var systemImage: String {
        switch self {
        case .wore:
            "checkmark.circle.fill"
        case .like:
            "hand.thumbsup.fill"
        case .dislike:
            "hand.thumbsdown.fill"
        case .skip:
            "arrow.triangle.2.circlepath"
        case .save:
            "bookmark.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wore, .save, .like:
            DesignSystem.accent
        case .dislike:
            DesignSystem.wine
        case .skip:
            DesignSystem.secondaryInk
        }
    }

    var showsLookbookAction: Bool {
        switch self {
        case .wore, .save:
            true
        case .like, .dislike, .skip:
            false
        }
    }

    func confirmation(for feedbackType: FeedbackType, outcome: TodayFeedbackRecorder.RecordOutcome) -> String {
        if outcome == .alreadyRecorded {
            switch feedbackType {
            case .wore:
                return L10n.text("today.confirmation.already_worn")
            case .saved:
                return L10n.text("today.confirmation.already_saved")
            case .liked, .disliked, .skipped, .swapped:
                break
            }
        }

        return switch self {
        case .wore:
            L10n.text("today.confirmation.wore")
        case .like:
            L10n.text("today.confirmation.like")
        case .dislike:
            L10n.text("today.confirmation.dislike")
        case .skip:
            L10n.text("today.confirmation.skip")
        case .save:
            L10n.text("today.confirmation.save")
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [
            ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self
        ], inMemory: true)
}
