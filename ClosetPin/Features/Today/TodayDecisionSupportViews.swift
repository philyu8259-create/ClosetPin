import SwiftUI

struct TodayDecisionGuideCard: View {
    private let steps: [(titleKey: String, bodyKey: String, icon: String)] = [
        ("today.decision.user.title", "today.decision.user.body", "hand.tap.fill"),
        ("today.decision.ai.title", "today.decision.ai.body", "sparkles"),
        ("today.decision.final.title", "today.decision.final.body", "checkmark.seal.fill")
    ]

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(steps.enumerated()), id: \.element.titleKey) { index, step in
                DecisionGuideStep(
                    title: L10n.text(step.titleKey),
                    icon: step.icon,
                    isPrimary: index == 1
                )

                if index < steps.count - 1 {
                    Image(systemName: "chevron.forward")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignSystem.border)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.paper.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.54), lineWidth: 1)
        }
        .accessibilityIdentifier("todayDecisionGuide")
    }
}

private struct DecisionGuideStep: View {
    let title: String
    let icon: String
    let isPrimary: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isPrimary ? DesignSystem.accent.opacity(0.16) : DesignSystem.paper.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(isPrimary ? DesignSystem.accent.opacity(0.45) : DesignSystem.border, lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPrimary ? DesignSystem.accent : DesignSystem.secondaryInk)
            }

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isPrimary ? DesignSystem.accent : DesignSystem.secondaryInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
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
