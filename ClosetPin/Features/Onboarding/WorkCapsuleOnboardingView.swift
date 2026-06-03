import SwiftData
import SwiftUI

struct WorkCapsuleOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeSheet: OnboardingSheet?
    @State private var saveError: String?

    let onCompleted: () -> Void
    let onStartAdding: (() -> Void)?

    init(
        onCompleted: @escaping () -> Void = {},
        onStartAdding: (() -> Void)? = nil
    ) {
        self.onCompleted = onCompleted
        self.onStartAdding = onStartAdding
    }

    private let checklistItems = [
        "onboarding.checklist.3_tops",
        "onboarding.checklist.2_bottoms",
        "onboarding.checklist.1_blazer_or_work_layer",
        "onboarding.checklist.2_shoes",
        "onboarding.checklist.1_bag"
    ]

    private let occasionItems: [(titleKey: String, icon: String)] = [
        ("onboarding.occasion.workdays", "briefcase.fill"),
        ("onboarding.occasion.meetings", "person.2.fill"),
        ("onboarding.occasion.banquets", "sparkles"),
        ("onboarding.occasion.weekends", "sun.max.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    onboardingImage
                    header
                    actions
                    checklist
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("onboarding.nav_title"))
            .alert(L10n.text("onboarding.sample_error_title"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(L10n.text("common.ok"), role: .cancel) {}
            } message: {
                Text(saveError ?? L10n.text("common.try_again"))
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addItem:
                    AddEditItemView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("onboarding.title"))
                .font(.largeTitle.bold())
                .foregroundStyle(DesignSystem.ink)
                .accessibilityIdentifier("workCapsuleOnboardingTitle")

            Text(L10n.text("onboarding.subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            occasionPromise
        }
    }

    private var occasionPromise: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label(L10n.text("onboarding.occasion.title"), systemImage: "square.grid.2x2.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)

            Text(L10n.text("onboarding.occasion.body"))
                .font(.caption)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(occasionItems, id: \.titleKey) { item in
                    OnboardingOccasionPill(title: L10n.text(item.titleKey), systemImage: item.icon)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.paper.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.5), lineWidth: 1)
        }
        .accessibilityIdentifier("onboardingOccasionPromise")
    }

    private var onboardingImage: some View {
        BundledPNGImage(name: "work-capsule-onboarding")
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("onboarding.checklist.title"))
                .font(.headline)
                .foregroundStyle(DesignSystem.ink)

            VStack(spacing: 12) {
                ForEach(checklistItems, id: \.self) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignSystem.accent)
                            .accessibilityHidden(true)
                        Text(L10n.text(item))
                            .font(.body)
                            .foregroundStyle(DesignSystem.ink)
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .background(DesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                addSampleCapsule()
            } label: {
                Label(L10n.text("onboarding.use_sample"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignSystem.accent)
            .accessibilityIdentifier("useSampleCapsuleButton")

            Button {
                if let onStartAdding {
                    onStartAdding()
                }
                activeSheet = .addItem
            } label: {
                Label(L10n.text("onboarding.start_adding"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(DesignSystem.accent)
            .accessibilityIdentifier("startAddingClothesButton")
        }
    }

    private func addSampleCapsule() {
        do {
            try WorkCapsuleSeeder.insertSampleCapsule(in: modelContext)
            onCompleted()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct OnboardingOccasionPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(DesignSystem.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.accent.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

private enum OnboardingSheet: Identifiable {
    case addItem

    var id: String {
        switch self {
        case .addItem:
            "addItem"
        }
    }
}

#Preview {
    WorkCapsuleOnboardingView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
