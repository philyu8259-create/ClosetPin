import SwiftUI

struct TodayDecisionGuideCard: View {
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

struct TodaySeasonAutoCard: View {
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
