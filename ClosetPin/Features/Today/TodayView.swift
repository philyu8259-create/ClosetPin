import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    @State private var scenario: OutfitScenario = .dailyOffice
    @State private var season: SeasonTag = .spring
    @State private var pendingActionIDs: Set<String> = []
    @State private var confirmation: TodayConfirmation?
    @State private var saveError: String?
    @State private var lastAppliedPreferenceScenario: OutfitScenario?

    let onOpenLooks: (() -> Void)?
    let onOpenCloset: (() -> Void)?

    private let engine = RecommendationEngine()
    private let feedbackRecorder = TodayFeedbackRecorder()

    init(onOpenLooks: (() -> Void)? = nil, onOpenCloset: (() -> Void)? = nil) {
        self.onOpenLooks = onOpenLooks
        self.onOpenCloset = onOpenCloset
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.editorial) {
                    editorialHero
                    contextStrip

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

    private var recommendationName: String {
        switch scenario {
        case .dailyOffice:
            L10n.text("today.best.name.daily_office")
        case .importantMeeting:
            L10n.text("today.best.name.important_meeting")
        }
    }

    private var currentPreference: UserPreference? {
        preferences.first
    }

    private func applyPreferenceDefaultsIfNeeded() {
        let preferredScenario = currentPreference?.defaultScenario ?? .dailyOffice
        guard lastAppliedPreferenceScenario == nil || scenario == lastAppliedPreferenceScenario else {
            return
        }

        scenario = preferredScenario
        lastAppliedPreferenceScenario = preferredScenario
    }

    private var missingRecommendationMessage: String {
        let requiredTypes: [ClothingType] = scenario == .importantMeeting
            ? [.top, .bottom, .shoes, .blazer]
            : [.top, .bottom, .shoes]
        let threshold = scenario == .importantMeeting ? 4 : 2

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
                height: 380
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
