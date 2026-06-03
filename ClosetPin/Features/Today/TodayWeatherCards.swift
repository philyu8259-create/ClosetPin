import SwiftUI

struct TomorrowPrepCard: View {
    let weatherSummary: String
    let recommendationName: String?
    let decisionSummary: String
    let tips: [String]
    let attributionName: String?
    let attributionURL: URL?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                    Label(L10n.text("today.tomorrow.prep.title"), systemImage: "cloud.sun.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.secondaryInk)

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    if let attributionName {
                        Text(L10n.string("today.tomorrow.attribution.format", arguments: attributionName))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .lineLimit(1)
                    }
                }
                .accessibilityIdentifier("tomorrowPrepTitle")

                Text(weatherSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tomorrowPrepWeatherSummary")

                if let recommendationName {
                    Label(recommendationName, systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityIdentifier("tomorrowPrepRecommendationName")
                }

                Text(decisionSummary)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tomorrowPrepDecisionSummary")

                if let firstTip = tips.first {
                    Label(firstTip, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("tomorrowPrepTip_0")
                }

                if let attributionURL {
                    Link(L10n.text("today.tomorrow.attribution.link"), destination: attributionURL)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .accessibilityIdentifier("tomorrowPrepWeatherAttributionLink")
                }
            }
        }
        .accessibilityIdentifier("tomorrowPrepCard")
    }
}

struct TomorrowWeatherStatusCard: View {
    let isLoading: Bool
    let locationName: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.accent.opacity(0.12))
                            .frame(width: 42, height: 42)

                        if isLoading {
                            ProgressView()
                                .tint(DesignSystem.accent)
                        } else {
                            Image(systemName: "cloud.sun")
                                .font(.headline)
                                .foregroundStyle(DesignSystem.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(L10n.text("today.tomorrow.weather_status.title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DesignSystem.ink)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        Label(actionTitle, systemImage: "gearshape.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(DesignSystem.accent)
                    .accessibilityIdentifier("tomorrowWeatherOpenSettingsButton")
                }
            }
        }
    }

    private var statusText: String {
        if isLoading {
            return L10n.string("today.tomorrow.weather_loading.format", arguments: locationName)
        }

        return message
    }
}
