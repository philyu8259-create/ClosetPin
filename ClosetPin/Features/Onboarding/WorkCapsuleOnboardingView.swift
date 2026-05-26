import SwiftData
import SwiftUI

struct WorkCapsuleOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var entryMessage: String?
    @State private var saveError: String?

    private let checklistItems = [
        "onboarding.checklist.3_tops",
        "onboarding.checklist.2_bottoms",
        "onboarding.checklist.1_blazer_or_work_layer",
        "onboarding.checklist.2_shoes",
        "onboarding.checklist.1_bag"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    checklist
                    actions
                }
                .padding(24)
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
        }
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
        .padding(18)
        .background(DesignSystem.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                entryMessage = L10n.text("onboarding.entry_coming")
            } label: {
                Label(L10n.text("onboarding.start_adding"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignSystem.accent)
            .accessibilityIdentifier("startAddingClothesButton")

            Button {
                addSampleCapsule()
            } label: {
                Label(L10n.text("onboarding.use_sample"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("useSampleCapsuleButton")

            if let entryMessage {
                Text(entryMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addSampleCapsule() {
        do {
            try WorkCapsuleSeeder.insertSampleCapsule(in: modelContext)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    WorkCapsuleOnboardingView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
