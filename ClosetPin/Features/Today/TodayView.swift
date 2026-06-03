import Foundation
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    private static let confirmationDismissDelay: Duration = .seconds(3)

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
    @State private var seasonOverrideExpanded = false
    @State private var aiExplanations: [String: String] = [:]
    @State private var stylistRefreshCounter = 0
    @State private var heroRotationIndex = 0
    @State private var cachedCandidates: [OutfitCandidate] = []

    let onOpenLooks: (() -> Void)?
    let onOpenCloset: (() -> Void)?
    let onAddClosetItem: ((ClothingType?) -> Void)?
    let onOpenSettings: (() -> Void)?

    private let engine = RecommendationEngine()
    private let feedbackRecorder = TodayFeedbackRecorder()
    private let tomorrowWeatherProvider: any TomorrowWeatherProviding
    private let stylistExplanationPipeline: StylistExplanationPipeline

    init(
        onOpenLooks: (() -> Void)? = nil,
        onOpenCloset: (() -> Void)? = nil,
        onAddClosetItem: ((ClothingType?) -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        tomorrowWeatherProvider: any TomorrowWeatherProviding = WeatherKitTomorrowWeatherProvider(),
        stylistExplanationPipeline: StylistExplanationPipeline = .appDefault()
    ) {
        self.onOpenLooks = onOpenLooks
        self.onOpenCloset = onOpenCloset
        self.onAddClosetItem = onAddClosetItem
        self.onOpenSettings = onOpenSettings
        self.tomorrowWeatherProvider = tomorrowWeatherProvider
        self.stylistExplanationPipeline = stylistExplanationPipeline
    }

    private var candidates: [OutfitCandidate] {
        cachedCandidates
    }

    private var recommendationInputWeatherContext: TomorrowWeatherContext? {
        guard let currentPreference, currentPreference.tomorrowWeatherEnabled else {
            return nil
        }

        return tomorrowWeatherSnapshot?.context
    }

    private var displayedCandidates: [OutfitCandidate] {
        Array(orderedCandidates.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    dailyDashboard
                    editorialHero
                    contextStrip
                    tomorrowPrepSection
                    decisionSupportSection

                    if displayedCandidates.count > 1 {
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
            .onChange(of: scenario) { _, _ in
                resetHeroRotation()
            }
            .onChange(of: season) { _, _ in
                resetHeroRotation()
            }
            .task(id: recommendationRequestKey) {
                refreshRecommendations()
            }
            .task(id: tomorrowWeatherRequestKey) {
                await refreshTomorrowWeatherIfNeeded()
            }
            .task(id: stylistExplanationRequestKey) {
                await refreshStylistExplanationsIfNeeded()
            }
            .safeAreaInset(edge: .bottom) {
                if let confirmation {
                    ConfirmationBanner(
                        confirmation: confirmation,
                        onOpenLooks: onOpenLooks,
                        onUndo: undoFeedback
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
            if let heroCandidate = displayedCandidates.first {
                TodayEditorialHero(
                    candidate: heroCandidate,
                    title: recommendationName,
                    explanation: explanation(for: heroCandidate),
                    pendingActionIDs: pendingActionIDs,
                    onTryAnother: regenerateTodayLook,
                    onAction: { action in
                        record(action, for: heroCandidate)
                    }
                )
            } else {
                let missingRecommendation = missingRecommendationPrompt
                MissingRecommendationView(
                    message: missingRecommendation.message,
                    suggestedType: missingRecommendation.suggestedType,
                    onOpenCloset: onOpenCloset,
                    onAddClosetItem: onAddClosetItem
                )
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(OutfitScenario.allCases) { scenario in
                        ContextChip(title: scenario.displayName, value: scenario, selection: $scenario)
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityIdentifier("todayScenarioPicker")
        }
    }

    private var decisionSupportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            TodaySeasonAutoCard(season: $season, isExpanded: $seasonOverrideExpanded)
            TodayDecisionGuideCard()
        }
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            let alternatives = Array(displayedCandidates.dropFirst().enumerated())
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
                            explanation: explanation(for: candidate),
                            pendingActionIDs: pendingActionIDs,
                            onTryAnother: regenerateTodayLook,
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
                    recommendationName: tomorrowPrepRecommendationName(for: context),
                    decisionSummary: L10n.text("today.tomorrow.decision_summary"),
                    tips: TomorrowWeatherPreview.preparationTips(for: context),
                    attributionName: tomorrowWeatherSnapshot?.attributionName,
                    attributionURL: tomorrowWeatherSnapshot?.attributionURL
                )
            } else if shouldShowTomorrowWeatherStatus {
                TomorrowWeatherStatusCard(
                    isLoading: tomorrowWeatherIsLoading,
                    locationName: currentPreference?.tomorrowWeatherLocationName ?? "",
                    message: tomorrowWeatherMessage ?? L10n.text("today.tomorrow.weather_missing_location"),
                    actionTitle: shouldPromptForTomorrowWeatherCity ? L10n.text("today.tomorrow.add_city_settings") : nil,
                    action: shouldPromptForTomorrowWeatherCity ? onOpenSettings : nil
                )
            }
        }
    }

    private func tomorrowPrepRecommendationName(for context: TomorrowWeatherContext) -> String? {
        let weatherCandidate = engine.recommend(
            input: RecommendationInput(
                scenario: scenario,
                season: season,
                tomorrow: TomorrowRecommendationInput(weatherContext: recommendationInputWeatherContext ?? context),
                maximumResults: 1,
                preferredFormality: currentPreference?.preferredFormality
            ),
            items: clothingItems,
            feedback: feedback
        ).first ?? candidates.first

        guard weatherCandidate != nil else { return nil }
        return L10n.string("today.tomorrow.recommendation_name.format", arguments: recommendationName)
    }

    private var activeTomorrowWeatherContext: TomorrowWeatherContext? {
        tomorrowWeatherSnapshot?.context ?? TomorrowWeatherPreview.context
    }

    private var shouldShowTomorrowWeatherStatus: Bool {
        currentPreference?.tomorrowWeatherEnabled == true
    }

    private var shouldPromptForTomorrowWeatherCity: Bool {
        guard let currentPreference, currentPreference.tomorrowWeatherEnabled else { return false }
        return !currentPreference.canRequestTomorrowWeather
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

    private var recommendationRequestKey: String {
        let preferenceKey = currentPreference.map {
            let trimmedLocation = $0.tomorrowWeatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970):\($0.preferredFormality):\($0.tomorrowWeatherEnabled ? 1 : 0):\(trimmedLocation)"
        } ?? "no-preference"
        let itemKey = clothingItems.map {
            "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)"
        }.joined(separator: "|")
        let feedbackKey = feedback.map {
            "\($0.id.uuidString):\($0.createdAt.timeIntervalSince1970)"
        }.joined(separator: "|")
        let weatherContextKey = recommendationInputWeatherContext.map {
            "\($0.condition.rawValue):\($0.minTemperatureCelsius):\($0.maxTemperatureCelsius):\($0.precipitationProbability):\($0.windSpeedKph)"
        } ?? ""

        return [
            scenario.rawValue,
            season.rawValue,
            preferenceKey,
            itemKey,
            feedbackKey,
            weatherContextKey
        ].joined(separator: "::")
    }

    private var orderedCandidates: [OutfitCandidate] {
        guard !candidates.isEmpty else { return [] }
        let safeOffset = heroRotationIndex % candidates.count
        return Array(candidates.dropFirst(safeOffset)) + Array(candidates.prefix(safeOffset))
    }

    private var tomorrowWeatherRequestKey: String {
        guard let currentPreference else { return "none" }
        return [
            currentPreference.tomorrowWeatherEnabled ? "enabled" : "disabled",
            currentPreference.tomorrowWeatherLocationName
        ].joined(separator: ":")
    }

    private var stylistExplanationRequestKey: String {
        [
            scenario.rawValue,
            season.rawValue,
            "\(stylistRefreshCounter)",
            orderedCandidates.map(\.id).joined(separator: "|")
        ].joined(separator: ":")
    }

    private var dailyDashboard: some View {
        DailyStylingDashboardCard(
            scenarioName: scenario.displayName,
            seasonName: season.displayName,
            closetSummary: L10n.string("today.dashboard.closet_ready.format", arguments: readyItemCount),
            hasRecommendation: candidates.first != nil,
            onGenerate: regenerateTodayLook
        )
    }

    private var readyItemCount: Int {
        clothingItems.filter { item in
            item.resolvedStatus == .available && item.seasons.contains(season)
        }.count
    }

    private func applyPreferenceDefaultsIfNeeded() {
        let preferredScenario = currentPreference?.defaultScenario ?? .dailyOffice
        guard lastAppliedPreferenceScenario == nil || scenario == lastAppliedPreferenceScenario else {
            return
        }

        scenario = preferredScenario
        lastAppliedPreferenceScenario = preferredScenario
    }

    private func refreshRecommendations() {
        let updatedCandidates = engine.recommend(
            input: RecommendationInput(
                scenario: scenario,
                season: season,
                tomorrow: TomorrowRecommendationInput(weatherContext: recommendationInputWeatherContext),
                maximumResults: 3,
                preferredFormality: currentPreference?.preferredFormality
            ),
            items: clothingItems,
            feedback: feedback
        )

        let previousCandidateIDs = cachedCandidates.map(\.id)
        let updatedCandidateIDs = updatedCandidates.map(\.id)
        cachedCandidates = updatedCandidates

        if previousCandidateIDs != updatedCandidateIDs {
            heroRotationIndex = 0
            let validIDs = Set(updatedCandidateIDs)
            aiExplanations = aiExplanations.filter { validIDs.contains($0.key) }
        }
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

    private var missingRecommendationPrompt: MissingRecommendationPrompt {
        let requiredTypes = requiredTypes(for: scenario)
        let threshold = requiredFormality(for: scenario)

        for type in requiredTypes {
            let availableSeasonItems = clothingItems.filter { item in
                item.resolvedType == type
                    && item.resolvedStatus == .available
                    && item.seasons.contains(season)
            }

            if availableSeasonItems.isEmpty {
                return MissingRecommendationPrompt(
                    message: L10n.string(
                        "today.missing.add_one.format",
                        arguments: type.missingItemPhrase, scenario.shortName
                    ),
                    suggestedType: type
                )
            }

            if availableSeasonItems.allSatisfy({ $0.formalityLevel < threshold }) {
                return MissingRecommendationPrompt(
                    message: L10n.string(
                        "today.missing.add_formal.format",
                        arguments: type.missingItemPhrase, scenario.shortName
                    ),
                    suggestedType: type
                )
            }
        }

        return MissingRecommendationPrompt(
            message: L10n.text("today.missing.available_or_season"),
            suggestedType: nil
        )
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

    private func explanation(for candidate: OutfitCandidate) -> String {
        aiExplanations[candidate.id] ?? TodayRecommendationExplanation.text(for: candidate, scenario: scenario)
    }

    private func refreshStylistExplanationsIfNeeded() async {
        let currentCandidates = orderedCandidates
        guard !currentCandidates.isEmpty else {
            aiExplanations = [:]
            return
        }

        let currentCandidateIDs = Set(currentCandidates.map(\.id))
        aiExplanations = aiExplanations.filter { currentCandidateIDs.contains($0.key) }

        for candidate in currentCandidates where aiExplanations[candidate.id] == nil {
            let explanation = await stylistExplanationPipeline.explanation(for: candidate, scenario: scenario)
            guard currentCandidateIDs.contains(candidate.id) else { continue }
            aiExplanations[candidate.id] = explanation
        }
    }

    private func regenerateTodayLook() {
        aiExplanations = [:]
        withAnimation(.snappy(duration: 0.22)) {
            seasonOverrideExpanded = false
            if !candidates.isEmpty {
                heroRotationIndex = (heroRotationIndex + 1) % candidates.count
            }
        }
        stylistRefreshCounter += 1
    }

    private func resetHeroRotation() {
        heroRotationIndex = 0
        stylistRefreshCounter += 1
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
                explanation: explanation(for: candidate),
                in: modelContext
            )

            let nextConfirmation = TodayConfirmation(
                message: action.confirmation(for: action.feedbackType, outcome: result.outcome),
                showsLookbookAction: action.showsLookbookAction,
                undoAction: action.undoAction(for: result)
            )
            withAnimation(.snappy) {
                confirmation = nextConfirmation
            }

            Task {
                try? await Task.sleep(for: Self.confirmationDismissDelay)
                await MainActor.run {
                    guard confirmation == nextConfirmation else { return }
                    withAnimation(.snappy(duration: 0.22)) {
                        confirmation = nil
                    }
                }
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func undoFeedback(_ undoAction: TodayUndoAction) {
        do {
            let storedFeedback = try modelContext.fetch(FetchDescriptor<OutfitFeedback>())
                .first { $0.id == undoAction.feedbackID }
            if let storedFeedback {
                modelContext.delete(storedFeedback)
            }

            if let outfitID = undoAction.outfitID {
                let storedOutfit = try modelContext.fetch(FetchDescriptor<Outfit>())
                    .first { $0.id == outfitID }
                if let storedOutfit {
                    modelContext.delete(storedOutfit)
                }
            }

            try modelContext.save()
            withAnimation(.snappy(duration: 0.22)) {
                confirmation = TodayConfirmation(
                    message: L10n.text("today.confirmation.undone"),
                    showsLookbookAction: false,
                    undoAction: nil
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
#if DEBUG
        guard let rawContext = ProcessInfo.processInfo.environment[environmentKey]
            ?? UserDefaults.standard.string(forKey: environmentKey)
            ?? rawContextFromArguments else {
            return nil
        }

        return context(from: rawContext)
#else
        nil
#endif
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

private struct DailyStylingDashboardCard: View {
    let scenarioName: String
    let seasonName: String
    let closetSummary: String
    let hasRecommendation: Bool
    let onGenerate: () -> Void

    var body: some View {
        LuxurySurfaceCard(isElevated: true) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(L10n.text("today.dashboard.kicker"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignSystem.accent)
                            .textCase(.uppercase)

                        Text(L10n.text("today.dashboard.title"))
                            .font(DesignSystem.editorialDisplayFont(size: 24))
                            .foregroundStyle(DesignSystem.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignSystem.premiumGold)
                        .frame(width: 42, height: 42)
                        .background(DesignSystem.premiumGold.opacity(0.16))
                        .clipShape(Circle())
                }

                Text(L10n.text("today.dashboard.body"))
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    DashboardTag(title: scenarioName, icon: "calendar.badge.checkmark")
                    DashboardTag(title: seasonName, icon: "leaf.fill")
                    DashboardTag(title: closetSummary, icon: "hanger")
                }

                Button(action: onGenerate) {
                    Label(
                        hasRecommendation ? L10n.text("today.dashboard.generate_again") : L10n.text("today.dashboard.generate"),
                        systemImage: "wand.and.sparkles"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(DesignSystem.accent)
                .accessibilityIdentifier("todayGenerateLookButton")
            }
        }
        .accessibilityIdentifier("todayDailyDashboard")
    }
}

private struct DashboardTag: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .foregroundStyle(DesignSystem.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DesignSystem.surface.opacity(0.86))
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
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
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(steps.enumerated()), id: \.element.titleKey) { index, step in
                Label(L10n.text(step.titleKey), systemImage: step.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(index == 1 ? DesignSystem.accent : DesignSystem.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)

                if index < steps.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DesignSystem.secondaryInk.opacity(0.65))
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
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

private struct TodaySeasonAutoCard: View {
    @Binding var season: SeasonTag
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DesignSystem.accent)
                    .frame(width: 30, height: 30)
                    .background(DesignSystem.accent.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("today.season.auto.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.secondaryInk)

                    Text(L10n.string("today.season.auto.current.format", arguments: season.displayName))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)
                }

                Spacer(minLength: DesignSystem.Spacing.sm)
            }

            Text(L10n.text("today.season.auto_note"))
                .font(.caption2)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Label(
                    L10n.text("today.season.override.button"),
                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                )
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(DesignSystem.accent)
            .accessibilityLabel(L10n.text("today.season.override.accessibility"))
            .accessibilityIdentifier("todaySeasonOverrideButton")

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(SeasonTag.allCases) { season in
                            ContextChip(title: season.displayName, value: season, selection: $season)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .accessibilityIdentifier("todaySeasonPicker")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.paper.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.52), lineWidth: 1)
        }
        .accessibilityIdentifier("todaySeasonAutoCard")
    }
}

private struct TomorrowPrepCard: View {
    let weatherSummary: String
    let recommendationName: String?
    let decisionSummary: String
    let tips: [String]
    let attributionName: String?
    let attributionURL: URL?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tomorrowPrepWeatherSummary")

                if let recommendationName {
                    Label(recommendationName, systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityIdentifier("tomorrowPrepRecommendationName")
                }

                Text(decisionSummary)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tomorrowPrepDecisionSummary")

                if let firstTip = tips.first {
                    Label(firstTip, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("tomorrowPrepTip_0")
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
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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

                if let actionTitle, let action {
                    Button(action: action) {
                        Label(actionTitle, systemImage: "gearshape.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(DesignSystem.accent)
                    .accessibilityIdentifier("tomorrowWeatherOpenSettingsButton")
                }
            }
        }
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
    let onTryAnother: () -> Void
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            LuxurySurfaceCard(isElevated: true) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Label(L10n.text("today.edit.kicker"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)

                    Text(title)
                        .font(DesignSystem.editorialDisplayFont(size: 30))
                        .foregroundStyle(DesignSystem.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    MatchPill(title: L10n.text("today.match.best"), icon: "seal.fill")
                        .padding(.top, DesignSystem.Spacing.xs)

                    TodayActionPanel(
                        candidate: candidate,
                        index: 0,
                        pendingActionIDs: pendingActionIDs,
                        onTryAnother: onTryAnother,
                        onAction: onAction
                    )
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }

            EditorialImageSurface(
                image: coverImage,
                height: 148
            ) {
                Text(L10n.text("today.visual.kicker"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .allowsHitTesting(false)

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
    let onTryAnother: () -> Void
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    MatchPill(title: matchTitle, icon: "sparkle.magnifyingglass")
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
                    onTryAnother: onTryAnother,
                    onAction: onAction
                )
            }
        }
    }

    private var matchTitle: String {
        index == 1 ? L10n.text("today.match.alt_sharp") : L10n.text("today.match.alt_easy")
    }
}

private struct MatchPill: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(DesignSystem.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignSystem.accent.opacity(0.1))
            .clipShape(Capsule(style: .continuous))
            .accessibilityIdentifier("todayMatchPill")
    }
}

private struct TodayActionPanel: View {
    let candidate: OutfitCandidate
    let index: Int
    let pendingActionIDs: Set<String>
    let onTryAnother: () -> Void
    let onAction: (TodayFeedbackAction) -> Void

    private let negativeFeedbackActions: [TodayFeedbackAction] = [.dislike]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    onAction(.wore)
                } label: {
                    Label(TodayFeedbackAction.wore.title, systemImage: TodayFeedbackAction.wore.systemImage)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
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
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.accent)
                .disabled(isPending(.save))
                .accessibilityIdentifier("todayFeedback_saved_\(index)")

                Button {
                    onAction(.swap)
                    onTryAnother()
                } label: {
                    Label(TodayFeedbackAction.swap.title, systemImage: TodayFeedbackAction.swap.systemImage)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.secondaryInk)
                .disabled(isPending(.swap))
                .accessibilityIdentifier("todayTryAnother_\(index)")

            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(L10n.text("today.feedback.tune_title"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(1)

                Spacer(minLength: DesignSystem.Spacing.sm)

                Menu {
                    ForEach(negativeFeedbackActions) { action in
                        Button {
                            onAction(action)
                        } label: {
                            Label(action.menuTitle, systemImage: action.systemImage)
                        }
                        .disabled(isPending(action))
                    }
                } label: {
                    Label(L10n.text("today.feedback.more"), systemImage: "ellipsis.circle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(DesignSystem.paper.opacity(0.86))
                        .clipShape(Capsule(style: .continuous))
                }
                .tint(DesignSystem.secondaryInk)
                .accessibilityIdentifier("todayFeedbackMore_\(index)")
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .fixedSize(horizontal: false, vertical: true)
            .background(DesignSystem.paper.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                    .stroke(DesignSystem.border.opacity(0.52), lineWidth: 1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func isPending(_ action: TodayFeedbackAction) -> Bool {
        pendingActionIDs.contains("\(candidate.id):\(action.feedbackType.rawValue)")
    }
}

private struct MissingRecommendationView: View {
    let message: String
    let suggestedType: ClothingType?
    let onOpenCloset: (() -> Void)?
    let onAddClosetItem: ((ClothingType?) -> Void)?

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

                if let onAddClosetItem {
                    Button {
                        onAddClosetItem(suggestedType)
                    } label: {
                        Label(L10n.text("today.missing.add_item"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(DesignSystem.accent)
                    .accessibilityIdentifier("todayMissingAddItemButton")
                } else if let onOpenCloset {
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
    }
}

private struct MissingRecommendationPrompt {
    let message: String
    let suggestedType: ClothingType?
}

private struct TodayConfirmation: Equatable {
    let message: String
    let showsLookbookAction: Bool
    let undoAction: TodayUndoAction?
}

private struct TodayUndoAction: Equatable {
    let feedbackID: UUID
    let outfitID: UUID?
}

private struct ConfirmationBanner: View {
    let confirmation: TodayConfirmation
    let onOpenLooks: (() -> Void)?
    let onUndo: (TodayUndoAction) -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            Text(confirmation.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
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

            if let undoAction = confirmation.undoAction {
                Button {
                    onUndo(undoAction)
                } label: {
                    Text(L10n.text("today.confirmation.undo"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignSystem.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white)
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("todayFeedbackUndoButton")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.accent)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todayFeedbackConfirmationBanner")
    }
}

private enum TodayFeedbackAction: CaseIterable, Identifiable {
    case wore
    case dislike
    case swap
    case save

    var id: String { feedbackType.rawValue }

    var feedbackType: FeedbackType {
        switch self {
        case .wore:
            .wore
        case .dislike:
            .disliked
        case .swap:
            .swapped
        case .save:
            .saved
        }
    }

    var title: String {
        switch self {
        case .wore:
            L10n.text("today.feedback.wore")
        case .dislike:
            L10n.text("today.feedback.dislike")
        case .swap:
            L10n.text("today.feedback.swap")
        case .save:
            L10n.text("today.feedback.save")
        }
    }

    var menuTitle: String {
        switch self {
        case .wore, .save:
            title
        case .dislike:
            L10n.text("today.feedback.avoid_style")
        case .swap:
            L10n.text("today.feedback.swap")
        }
    }

    var systemImage: String {
        switch self {
        case .wore:
            "checkmark.circle.fill"
        case .dislike:
            "hand.thumbsdown.fill"
        case .swap:
            "arrow.triangle.2.circlepath"
        case .save:
            "bookmark.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wore, .save, .swap:
            DesignSystem.accent
        case .dislike:
            DesignSystem.wine
        }
    }

    var showsLookbookAction: Bool {
        switch self {
        case .wore, .save:
            true
        case .dislike, .swap:
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
        case .dislike:
            L10n.text("today.confirmation.dislike")
        case .swap:
            L10n.text("today.confirmation.swap")
        case .save:
            L10n.text("today.confirmation.save")
        }
    }

    func undoAction(for result: TodayFeedbackRecorder.RecordResult) -> TodayUndoAction? {
        guard result.outcome == .recorded else { return nil }
        guard self != .wore else { return nil }
        return TodayUndoAction(feedbackID: result.feedback.id, outfitID: result.outfit?.id)
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
