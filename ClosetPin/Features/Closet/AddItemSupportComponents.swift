import SwiftUI

struct ClosetSeasonAutoCard: View {
    let selectedSeasons: Set<SeasonTag>
    let selectionSource: AddEditItemDraft.SeasonSelectionSource
    @Binding var isExpanded: Bool

    private var seasonSummary: String {
        let seasons = SeasonTag.allCases
            .filter { selectedSeasons.contains($0) }
            .map(\.displayName)

        guard !seasons.isEmpty else {
            return L10n.text("closet.season.none")
        }
        return seasons.joined(separator: ", ")
    }

    private var summaryText: String {
        switch selectionSource {
        case .systemDate:
            return L10n.string("closet.season.auto.current.format", arguments: seasonSummary)
        case .photoSuggestion:
            return L10n.string("closet.season.auto.photo.format", arguments: seasonSummary)
        case .manual:
            return seasonSummary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("closet.season.auto.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
            }

            Spacer(minLength: DesignSystem.Spacing.sm)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(L10n.text("closet.season.change"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(DesignSystem.accent.opacity(0.1))
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("closetSeasonChangeButton")
        }
        .padding(12)
        .background(DesignSystem.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SeasonShortcutRow: View {
    let selectCurrentSeason: () -> Void
    let selectYearRound: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            SeasonShortcutButton(
                title: L10n.text("closet.season.current_shortcut"),
                systemImage: "calendar.badge.clock",
                accessibilityIdentifier: "seasonShortcut_current",
                action: selectCurrentSeason
            )

            SeasonShortcutButton(
                title: L10n.text("closet.season.year_round_shortcut"),
                systemImage: "arrow.triangle.2.circlepath",
                accessibilityIdentifier: "seasonShortcut_yearRound",
                action: selectYearRound
            )
        }
    }
}

private struct SeasonShortcutButton: View {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(DesignSystem.accent)
                .background(DesignSystem.accent.opacity(0.1))
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct EssentialsChecklistGrid: View {
    let draft: AddEditItemDraft

    private var missingTitles: [String] {
        var titles: [String] = []

        if !draft.hasPhoto {
            titles.append(L10n.text("closet.save_checklist.photo"))
        }
        if !draft.hasColor {
            titles.append(L10n.text("closet.save_checklist.color"))
        }
        if !draft.hasSeasonSelection {
            titles.append(L10n.text("closet.save_checklist.season"))
        }

        return titles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if missingTitles.isEmpty {
                Label(L10n.text("closet.save_checklist.ready"), systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text(L10n.text("closet.save_checklist.title"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(missingTitles, id: \.self) { title in
                        EssentialsChecklistChip(title: title, isComplete: false)
                    }
                }

                Text(L10n.text("closet.save_checklist.action_hint"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .padding(.top, 2)
            }
        }
    }
}

private struct EssentialsChecklistChip: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isComplete ? DesignSystem.accent : DesignSystem.secondaryInk)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(isComplete ? DesignSystem.accent.opacity(0.08) : DesignSystem.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isComplete ? DesignSystem.accent.opacity(0.18) : DesignSystem.border.opacity(0.4), lineWidth: 1)
        }
    }
}

struct StatusSelectionGrid: View {
    @Binding var selection: ClothingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("closet.status.label"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(ClothingStatus.allCases) { status in
                    let isSelected = selection == status
                    Button {
                        selection = status
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: status.systemImage)
                                .font(.subheadline.weight(.semibold))
                            Text(status.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? .white : DesignSystem.ink)
                        .background(isSelected ? statusColor(for: status) : DesignSystem.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(statusColor(for: status).opacity(isSelected ? 0.16 : 0.24), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("statusOption_\(status.rawValue)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: ClothingStatus) -> Color {
        DesignSystem.statusColor(for: status)
    }
}
