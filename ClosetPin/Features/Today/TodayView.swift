import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var clothingItems: [ClothingItem]
    @Query(sort: \OutfitFeedback.createdAt, order: .reverse) private var feedback: [OutfitFeedback]

    @State private var scenario: OutfitScenario = .dailyOffice
    @State private var season: SeasonTag = .spring
    @State private var pendingActionIDs: Set<String> = []
    @State private var confirmationMessage: String?
    @State private var saveError: String?

    private let engine = RecommendationEngine()
    private let feedbackRecorder = TodayFeedbackRecorder()

    private var candidates: [OutfitCandidate] {
        engine.recommend(
            input: RecommendationInput(
                scenario: scenario,
                season: season,
                maximumResults: 3
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("today.title"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let confirmationMessage {
                    ConfirmationBanner(message: confirmationMessage)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
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
                MissingRecommendationView(message: missingRecommendationMessage)
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
                confirmationMessage = action.confirmation(for: action.feedbackType, outcome: result.outcome)
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
                height: 420
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label(L10n.text("today.edit.kicker"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.premiumGold)

                    Text(title)
                        .font(.largeTitle.weight(.semibold))
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
                .accessibilityIdentifier("todayFeedback_wore_0")

                Button {
                    onAction(.save)
                } label: {
                    Image(systemName: TodayFeedbackAction.save.systemImage)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.accent)
                .disabled(isPending(.save))
                .accessibilityLabel(TodayFeedbackAction.save.title)
                .accessibilityIdentifier("todayFeedback_saved_0")
            }

            OutfitVisualBoard(items: candidate.items)
                .accessibilityIdentifier("todayOutfitVisualBoard_0")
        }
    }

    private var coverImage: UIImage? {
        candidate.items.compactMap { WardrobePhoto.localImage(for: $0) }.first
    }

    private func isPending(_ action: TodayFeedbackAction) -> Bool {
        pendingActionIDs.contains("\(candidate.id):\(action.feedbackType.rawValue)")
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

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button {
                        onAction(.wore)
                    } label: {
                        Label(TodayFeedbackAction.wore.title, systemImage: TodayFeedbackAction.wore.systemImage)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(DesignSystem.accent)
                    .disabled(isPending(.wore))
                    .accessibilityIdentifier("todayFeedback_wore_\(index)")

                    Button {
                        onAction(.save)
                    } label: {
                        Label(TodayFeedbackAction.save.title, systemImage: TodayFeedbackAction.save.systemImage)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(DesignSystem.accent)
                    .disabled(isPending(.save))
                    .accessibilityIdentifier("todayFeedback_saved_\(index)")
                }
            }
        }
    }

    private func isPending(_ action: TodayFeedbackAction) -> Bool {
        pendingActionIDs.contains("\(candidate.id):\(action.feedbackType.rawValue)")
    }
}

private struct MissingRecommendationView: View {
    let message: String

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
            }
        }
        .accessibilityIdentifier("todayMissingRecommendation")
    }
}

private struct ConfirmationBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.accent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .accessibilityIdentifier("todayFeedbackConfirmation")
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
            "hand.thumbsup"
        case .dislike:
            "hand.thumbsdown"
        case .skip:
            "arrow.triangle.2.circlepath"
        case .save:
            "bookmark.fill"
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
