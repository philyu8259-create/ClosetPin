import SwiftUI

struct DailyStylingDashboardCard: View {
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

struct DashboardTag: View {
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
