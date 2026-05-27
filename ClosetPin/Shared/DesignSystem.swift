import SwiftUI

enum DesignSystem {
    static let cornerRadius: CGFloat = Radius.md
    static let spacing: CGFloat = Spacing.lg

    static let background = Color(hex: "F7F2EA")
    static let surface = Color(hex: "FFFDF8")
    static let surfaceElevated = Color.white
    static let ink = Color(hex: "171513")
    static let secondaryInk = Color(hex: "6F675E")
    static let accent = Color(hex: "0F5C55")
    static let premiumGold = Color(hex: "C8A96A")
    static let wine = Color(hex: "6B2E3A")
    static let border = Color(hex: "E7DED2")

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    static func statusColor(for status: ClothingStatus) -> Color {
        switch status {
        case .available:
            accent
        case .needsWash:
            Color(hex: "A1662F")
        case .needsRepair:
            wine
        case .inactive:
            secondaryInk
        }
    }
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }

        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)

        let red = Double((integer >> 16) & 0xFF) / 255
        let green = Double((integer >> 8) & 0xFF) / 255
        let blue = Double(integer & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}

struct LuxurySurfaceCard<Content: View>: View {
    let isElevated: Bool
    let content: Content

    init(isElevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.isElevated = isElevated
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isElevated ? DesignSystem.surfaceElevated : DesignSystem.surface)
            .clipShape(RoundedRectangle(cornerRadius: isElevated ? DesignSystem.Radius.lg : DesignSystem.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: isElevated ? DesignSystem.Radius.lg : DesignSystem.Radius.md, style: .continuous)
                    .stroke(isElevated ? DesignSystem.premiumGold.opacity(0.55) : DesignSystem.border, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(isElevated ? 0.08 : 0.03),
                radius: isElevated ? 16 : 6,
                x: 0,
                y: isElevated ? 8 : 3
            )
    }
}

struct ContextChip<Value: Hashable>: View {
    let title: String
    let value: Value
    @Binding var selection: Value

    var body: some View {
        Button {
            selection = value
        } label: {
            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .frame(minHeight: 38)
                .foregroundStyle(isSelected ? .white : DesignSystem.ink)
                .background(isSelected ? DesignSystem.accent : DesignSystem.surface)
                .clipShape(Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? DesignSystem.accent : DesignSystem.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var isSelected: Bool {
        selection == value
    }
}

struct StatusChip: View {
    let status: ClothingStatus

    var body: some View {
        Label(status.displayName, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule(style: .continuous))
            .accessibilityLabel(status.displayName)
    }

    private var statusColor: Color {
        DesignSystem.statusColor(for: status)
    }
}
