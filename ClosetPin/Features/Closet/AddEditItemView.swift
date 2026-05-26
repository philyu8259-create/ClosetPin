import PhotosUI
import SwiftData
import SwiftUI

struct AddEditItemDraft {
    var photoLocalPath: String = ""
    var type: ClothingType = .top
    var color: String = ""
    var selectedSeasons: Set<SeasonTag> = []
    var formalityLevel: Int = 3
    var warmthLevel: Int = 3
    var storageLocation: String = ""
    var status: ClothingStatus = .available
    var notes: String = ""

    init(item: ClothingItem? = nil) {
        guard let item else { return }

        photoLocalPath = item.photoLocalPath
        type = item.type
        color = item.color
        selectedSeasons = Set(item.seasons)
        formalityLevel = item.formalityLevel
        warmthLevel = item.warmthLevel
        storageLocation = item.storageLocation
        status = item.status
        notes = item.notes
    }

    var validationMessages: [String] {
        var messages: [String] = []
        if normalized(color).isEmpty {
            messages.append("Color is required.")
        }
        if selectedSeasons.isEmpty {
            messages.append("Select at least one season.")
        }
        if normalized(storageLocation).isEmpty {
            messages.append("Storage location is required.")
        }
        return messages
    }

    var canSave: Bool {
        validationMessages.isEmpty
    }

    mutating func toggleSeason(_ season: SeasonTag) {
        if selectedSeasons.contains(season) {
            selectedSeasons.remove(season)
        } else {
            selectedSeasons.insert(season)
        }
    }

    func makeItem() -> ClothingItem {
        ClothingItem(
            photoLocalPath: photoLocalPath,
            type: type,
            color: normalized(color),
            seasons: sortedSeasons,
            formalityLevel: formalityLevel,
            warmthLevel: warmthLevel,
            storageLocation: normalized(storageLocation),
            status: status,
            notes: normalized(notes)
        )
    }

    func apply(to item: ClothingItem) {
        item.photoLocalPath = photoLocalPath
        item.typeRawValue = type.rawValue
        item.color = normalized(color)
        item.seasonRawValues = sortedSeasons.map(\.rawValue)
        item.formalityLevel = formalityLevel
        item.warmthLevel = warmthLevel
        item.storageLocation = normalized(storageLocation)
        item.statusRawValue = status.rawValue
        item.notes = normalized(notes)
        item.updatedAt = Date()
    }

    private var sortedSeasons: [SeasonTag] {
        SeasonTag.allCases.filter { selectedSeasons.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AddEditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let item: ClothingItem?
    @State private var draft: AddEditItemDraft
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var saveError: String?

    init(item: ClothingItem? = nil) {
        self.item = item
        _draft = State(initialValue: AddEditItemDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                detailsSection
                seasonsSection
                levelsSection
                notesSection

                if !draft.canSave {
                    validationSection
                }
            }
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("saveItemButton")
                }
            }
            .alert("Item Was Not Saved", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose Photo")
                            .foregroundStyle(DesignSystem.ink)
                        Text("Photo storage will be connected later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .accessibilityIdentifier("itemPhotoPicker")
        }
    }

    private var detailsSection: some View {
        Section("Item Details") {
            Picker("Type", selection: $draft.type) {
                ForEach(ClothingType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField("Color", text: $draft.color)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("itemColorField")

            TextField("Storage Location", text: $draft.storageLocation)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("itemStorageField")

            Picker("Status", selection: $draft.status) {
                ForEach(ClothingStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
        }
    }

    private var seasonsSection: some View {
        Section("Seasons") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(SeasonTag.allCases) { season in
                    Button {
                        draft.toggleSeason(season)
                    } label: {
                        HStack {
                            Image(systemName: draft.selectedSeasons.contains(season) ? "checkmark.circle.fill" : "circle")
                            Text(season.displayName)
                            Spacer(minLength: 0)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(draft.selectedSeasons.contains(season) ? DesignSystem.accent.opacity(0.14) : Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("seasonToggle_\(season.rawValue)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var levelsSection: some View {
        Section("Fit For Workday") {
            Stepper("Formality: \(draft.formalityLevel)", value: $draft.formalityLevel, in: 1...5)
            Stepper("Warmth: \(draft.warmthLevel)", value: $draft.warmthLevel, in: 1...5)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $draft.notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var validationSection: some View {
        Section {
            ForEach(draft.validationMessages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        guard draft.canSave else { return }

        do {
            if let item {
                draft.apply(to: item)
            } else {
                modelContext.insert(draft.makeItem())
            }
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    AddEditItemView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
