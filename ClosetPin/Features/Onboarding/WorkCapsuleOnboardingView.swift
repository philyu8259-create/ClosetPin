import SwiftData
import SwiftUI

struct WorkCapsuleOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var entryMessage: String?
    @State private var saveError: String?

    private let checklistItems = [
        "3 tops",
        "2 bottoms",
        "1 blazer or work layer",
        "2 shoes",
        "1 bag"
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
            .navigationTitle("Work Capsule")
            .alert("Sample Capsule Was Not Added", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("10-Minute Work Capsule")
                .font(.largeTitle.bold())
                .foregroundStyle(DesignSystem.ink)
                .accessibilityIdentifier("workCapsuleOnboardingTitle")

            Text("Start with a small office-ready capsule for daily recommendations, meetings, and the days that need to feel easy.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recommended starter set")
                .font(.headline)
                .foregroundStyle(DesignSystem.ink)

            VStack(spacing: 12) {
                ForEach(checklistItems, id: \.self) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignSystem.accent)
                            .accessibilityHidden(true)
                        Text(item)
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
                entryMessage = "Clothing entry is coming next. Use Sample Capsule to explore recommendations now."
            } label: {
                Label("Start Adding Clothes", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignSystem.accent)
            .accessibilityIdentifier("startAddingClothesButton")

            Button {
                addSampleCapsule()
            } label: {
                Label("Use Sample Capsule", systemImage: "sparkles")
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
