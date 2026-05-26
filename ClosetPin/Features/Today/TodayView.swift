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
                VStack(alignment: .leading, spacing: 18) {
                    contextControls

                    if candidates.isEmpty {
                        MissingRecommendationView(message: missingRecommendationMessage)
                    } else {
                        recommendationList
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.background)
            .navigationTitle("Today")
            .safeAreaInset(edge: .bottom) {
                if let confirmationMessage {
                    ConfirmationBanner(message: confirmationMessage)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert("Feedback Was Not Saved", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private var contextControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Work context")
                .font(.headline)
                .foregroundStyle(DesignSystem.ink)

            Picker("Scenario", selection: $scenario) {
                ForEach(OutfitScenario.allCases) { scenario in
                    Text(scenario.displayName).tag(scenario)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("todayScenarioPicker")

            Picker("Season", selection: $season) {
                ForEach(SeasonTag.allCases) { season in
                    Text(season.displayName).tag(season)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("todaySeasonPicker")
        }
        .padding(16)
        .background(DesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
    }

    private var recommendationList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recommended for \(scenario.displayName)")
                .font(.headline)
                .foregroundStyle(DesignSystem.ink)

            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                RecommendationCard(
                    index: index,
                    candidate: candidate,
                    explanation: TodayRecommendationExplanation.text(for: candidate, scenario: scenario),
                    pendingActionIDs: pendingActionIDs,
                    onAction: { action in
                        record(action, for: candidate)
                    }
                )
                .accessibilityIdentifier("todayRecommendationCard_\(index)")
            }
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
                return "Add one \(type.missingItemPhrase) to generate \(scenario.shortName) outfits."
            }

            if availableSeasonItems.allSatisfy({ $0.formalityLevel < threshold }) {
                return "Add or update one more formal \(type.missingItemPhrase) to generate \(scenario.shortName) outfits."
            }
        }

        return "Make one work item available or select a season with office-ready pieces."
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

private struct RecommendationCard: View {
    let index: Int
    let candidate: OutfitCandidate
    let explanation: String
    let pendingActionIDs: Set<String>
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Option \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ink)

                Spacer()

                Label("\(candidate.score)", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
                    .accessibilityLabel("Score \(candidate.score)")
            }

            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(candidate.items) { item in
                    TodayItemRow(item: item)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TodayFeedbackAction.allCases) { action in
                        Button {
                            onAction(action)
                        } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(pendingActionIDs.contains("\(candidate.id):\(action.feedbackType.rawValue)"))
                        .accessibilityIdentifier("todayFeedback_\(action.feedbackType.rawValue)_\(index)")
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(16)
        .background(DesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
    }
}

private struct TodayItemRow: View {
    let item: ClothingItem

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(item.color.todaySwatchColor)
                .frame(width: 30, height: 30)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
                .accessibilityHidden(true)

            Text(item.color)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)

            Text(item.type.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MissingRecommendationView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Outfit ingredients needed", systemImage: "exclamationmark.circle")
                .font(.headline)
                .foregroundStyle(DesignSystem.ink)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
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
            "Wore"
        case .like:
            "Like"
        case .dislike:
            "Dislike"
        case .skip:
            "Skip"
        case .save:
            "Save"
        }
    }

    var systemImage: String {
        switch self {
        case .wore:
            "checkmark.circle"
        case .like:
            "hand.thumbsup"
        case .dislike:
            "hand.thumbsdown"
        case .skip:
            "arrow.right.circle"
        case .save:
            "bookmark"
        }
    }

    func confirmation(for feedbackType: FeedbackType, outcome: TodayFeedbackRecorder.RecordOutcome) -> String {
        if outcome == .alreadyRecorded {
            switch feedbackType {
            case .wore:
                return "Already recorded as worn today."
            case .saved:
                return "Outfit already saved today."
            case .liked, .disliked, .skipped, .swapped:
                break
            }
        }

        return switch self {
        case .wore:
            "Recorded as worn."
        case .like:
            "Preference saved."
        case .dislike:
            "Feedback saved."
        case .skip:
            "Skipped for today."
        case .save:
            "Outfit saved."
        }
    }
}

private extension OutfitScenario {
    var displayName: String {
        switch self {
        case .dailyOffice:
            "Daily Office"
        case .importantMeeting:
            "Important Meeting"
        }
    }

    var shortName: String {
        switch self {
        case .dailyOffice:
            "office"
        case .importantMeeting:
            "meeting"
        }
    }
}

private extension ClothingType {
    var missingItemPhrase: String {
        switch self {
        case .top:
            "work top"
        case .bottom:
            "work bottom"
        case .blazer:
            "blazer or work layer"
        case .shoes:
            "pair of work shoes"
        case .bag:
            "work bag"
        case .accessory:
            "work accessory"
        case .outerwear:
            "work outerwear"
        }
    }
}

private extension String {
    var todaySwatchColor: Color {
        switch trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "black", "charcoal":
            .black
        case "white", "ivory", "cream":
            .white
        case "navy":
            Color(red: 0.03, green: 0.09, blue: 0.22)
        case "blue", "light blue":
            .blue
        case "gray", "grey":
            .gray
        case "brown", "tan", "camel":
            .brown
        case "green", "olive":
            .green
        case "red", "burgundy":
            .red
        default:
            DesignSystem.accent.opacity(0.35)
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
