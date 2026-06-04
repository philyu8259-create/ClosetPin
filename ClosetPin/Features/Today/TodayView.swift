import Foundation
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    private static let confirmationDismissDelay: Duration = .seconds(3)
    private static let heroAnchorID = "today-hero-anchor"

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
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        dailyDashboard(using: scrollProxy)
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
                    withAnimation(.snappy(duration: 0.22)) {
                        scrollProxy.scrollTo(Self.heroAnchorID, anchor: .top)
                    }
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
                .id(Self.heroAnchorID)
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

            LazyVGrid(columns: scenarioChipColumns, alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(OutfitScenario.allCases) { scenario in
                    ContextChip(title: scenario.displayName, value: scenario, selection: $scenario)
                        .accessibilityIdentifier("todayScenario_\(scenario.rawValue)")
                }
            }
            .accessibilityIdentifier("todayScenarioPicker")
        }
    }

    private var scenarioChipColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 132), spacing: DesignSystem.Spacing.sm)]
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

    private func dailyDashboard(using scrollProxy: ScrollViewProxy) -> some View {
        DailyStylingDashboardCard(
            scenarioName: scenario.displayName,
            seasonName: season.displayName,
            closetSummary: L10n.string("today.dashboard.closet_ready.format", arguments: readyItemCount),
            hasRecommendation: candidates.first != nil,
            onGenerate: {
                handleDashboardPrimaryAction(using: scrollProxy)
            }
        )
    }

    private var readyItemCount: Int {
        clothingItems.filter { item in
            item.resolvedStatus == .available && item.seasons.contains(season)
        }.count
    }

    private func handleDashboardPrimaryAction(using scrollProxy: ScrollViewProxy) {
        guard !candidates.isEmpty else {
            regenerateTodayLook()
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            scrollProxy.scrollTo(Self.heroAnchorID, anchor: .top)
        }
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
                maximumResults: 12,
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

#Preview {
    TodayView()
        .modelContainer(for: [
            ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self
        ], inMemory: true)
}
