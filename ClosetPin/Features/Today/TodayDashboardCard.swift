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
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(L10n.text("today.dashboard.kicker"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .tracking(0.45)
                            .textCase(.uppercase)

                        Text(L10n.text("today.dashboard.title"))
                            .font(DesignSystem.editorialDisplayFont(size: 24))
                            .foregroundStyle(DesignSystem.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DesignSystem.premiumGold)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .stroke(DesignSystem.premiumGold.opacity(0.28), lineWidth: 1)
                                .background(Circle().fill(DesignSystem.premiumGold.opacity(0.12)))
                        )
                        .clipShape(Circle())
                }

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
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(DesignSystem.ink)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .background(DesignSystem.surface.opacity(0.9))
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(DesignSystem.premiumGold.opacity(0.35), lineWidth: 0.8)
            }
    }
}
