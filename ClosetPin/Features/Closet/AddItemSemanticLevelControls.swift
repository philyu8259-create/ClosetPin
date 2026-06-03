import SwiftUI

enum FormalityLevelLabel: Int, CaseIterable {
    case casual = 1
    case commute = 2
    case business = 3
    case formal = 4
    case polished = 5

    var title: String {
        switch self {
        case .casual:
            L10n.text("closet.formality.casual")
        case .commute:
            L10n.text("closet.formality.smart")
        case .business:
            L10n.text("closet.formality.level_3")
        case .formal:
            L10n.text("closet.formality.level_4")
        case .polished:
            L10n.text("closet.formality.level_5")
        }
    }
}

enum WarmthLevelLabel: Int, CaseIterable {
    case light = 1
    case moderate = 2
    case warm = 3
    case heavier = 4
    case heavy = 5

    var title: String {
        switch self {
        case .light:
            L10n.text("closet.warmth.level_1")
        case .moderate:
            L10n.text("closet.warmth.medium")
        case .warm:
            L10n.text("closet.warmth.level_4")
        case .heavier:
            L10n.text("closet.warmth.level_4")
        case .heavy:
            L10n.text("closet.warmth.level_5")
        }
    }
}

struct FormalityLevelControl: View {
    let title: String
    let options: [FormalityLevelLabel]
    @Binding var selected: Int
    let selectedTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            Text(selectedTitle)
                .font(.caption)
                .foregroundStyle(DesignSystem.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.rawValue) { option in
                    Button {
                        selected = option.rawValue
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selected == option.rawValue ? .white : DesignSystem.ink)
                            .background(selected == option.rawValue ? DesignSystem.accent : DesignSystem.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("formalityLevel_\(option.rawValue)")
                    .accessibilityAddTraits(selected == option.rawValue ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct WarmthLevelControl: View {
    let title: String
    let options: [WarmthLevelLabel]
    @Binding var selected: Int
    let selectedTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            Text(selectedTitle)
                .font(.caption)
                .foregroundStyle(DesignSystem.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.rawValue) { option in
                    Button {
                        selected = option.rawValue
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selected == option.rawValue ? .white : DesignSystem.ink)
                            .background(selected == option.rawValue ? DesignSystem.accent : DesignSystem.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("warmthLevel_\(option.rawValue)")
                    .accessibilityAddTraits(selected == option.rawValue ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

func formalityLabel(for value: Int) -> String {
    FormalityLevelLabel(rawValue: clampedLevel(value))?.title
        ?? FormalityLevelLabel.casual.title
}

func warmthLabel(for value: Int) -> String {
    WarmthLevelLabel(rawValue: clampedLevel(value))?.title
        ?? WarmthLevelLabel.light.title
}

private func clampedLevel(_ value: Int) -> Int {
    max(1, min(5, value))
}
