import SwiftUI

struct TodayActionPanel: View {
    let candidate: OutfitCandidate
    let index: Int
    let pendingActionIDs: Set<String>
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

struct TodayConfirmation: Equatable {
    let message: String
    let showsLookbookAction: Bool
    let undoAction: TodayUndoAction?
}

struct TodayUndoAction: Equatable {
    let feedbackID: UUID
    let outfitID: UUID?
}

struct ConfirmationBanner: View {
    let confirmation: TodayConfirmation
    let onOpenLooks: (() -> Void)?
    let onUndo: (TodayUndoAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text(confirmation.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("todayFeedbackConfirmationText")
            }

            if hasActionRow {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if confirmation.showsLookbookAction, let onOpenLooks {
                        Button(action: onOpenLooks) {
                            Text(L10n.text("today.confirmation.view_looks"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.2))
                                .clipShape(Capsule(style: .continuous))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(.white.opacity(0.52), lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("todayFeedbackViewLooksButton")
                    }

                    if let undoAction = confirmation.undoAction {
                        Button {
                            onUndo(undoAction)
                        } label: {
                            Text(L10n.text("today.confirmation.undo"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.2))
                                .clipShape(Capsule(style: .continuous))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(.white.opacity(0.52), lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("todayFeedbackUndoButton")
                    }
                }
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

    private var hasActionRow: Bool {
        (confirmation.showsLookbookAction && onOpenLooks != nil) || confirmation.undoAction != nil
    }
}

enum TodayFeedbackAction: CaseIterable, Identifiable {
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
        return TodayUndoAction(feedbackID: result.feedback.id, outfitID: result.outfit?.id)
    }
}
