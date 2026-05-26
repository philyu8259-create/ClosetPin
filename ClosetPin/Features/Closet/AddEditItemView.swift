import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddEditItemDraft {
    var itemID: UUID = UUID()
    var photoLocalPath: String = ""
    var pendingPhotoJPEGData: Data?
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

        itemID = item.id
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
        if normalized(photoLocalPath).isEmpty && pendingPhotoJPEGData == nil {
            messages.append("Photo is required.")
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
            id: itemID,
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
    private let imageStore: ImageStore
    @State private var draft: AddEditItemDraft
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isCameraPresented = false
    @State private var saveError: String?
    @State private var photoError: String?

    init(item: ClothingItem? = nil, imageStore: ImageStore = ImageStore()) {
        self.item = item
        self.imageStore = imageStore
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await persistSelectedPhoto(newItem)
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraCaptureView { image in
                    stageCameraImage(image)
                }
            }
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            photoError = "Camera is not available on this device."
                            return
                        }
                        isCameraPresented = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    .accessibilityIdentifier("takePhotoButton")

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("chooseFromLibraryButton")
                }

                if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Text("Camera is not available on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Add a clear photo for this work piece.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

#if DEBUG
            if ProcessInfo.processInfo.environment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] == "1" {
                Button("Use Test Photo") {
                    draft.pendingPhotoJPEGData = Data([0xFF, 0xD8, 0xFF, 0xD9])
                    photoError = nil
                }
                .accessibilityIdentifier("useTestPhotoButton")
            }
#endif

            if draft.pendingPhotoJPEGData != nil {
                Label("Photo ready to save.", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.accent)
            } else if !draft.photoLocalPath.isEmpty {
                Label("Photo saved locally.", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.accent)
            }

            if let photoError {
                Label(photoError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
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
                    let isSelected = draft.selectedSeasons.contains(season)
                    Button {
                        draft.toggleSeason(season)
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            Text(season.displayName)
                            Spacer(minLength: 0)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? DesignSystem.accent.opacity(0.14) : Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("seasonToggle_\(season.rawValue)")
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
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

        var insertedItem: ClothingItem?
        let snapshot = item.map(ClothingItemSnapshot.init(item:))
        var stagedWrite: StagedPhotoWrite?

        do {
            var finalizedDraft = draft
            if let pendingPhotoJPEGData = draft.pendingPhotoJPEGData {
                let write = try ClosetItemPhotoPersistence.stageJPEGData(
                    pendingPhotoJPEGData,
                    id: draft.itemID,
                    imageStore: imageStore
                )
                stagedWrite = write
                finalizedDraft.photoLocalPath = write.finalURL.path
                finalizedDraft.pendingPhotoJPEGData = nil
            }

            if let item {
                finalizedDraft.apply(to: item)
            } else {
                let newItem = finalizedDraft.makeItem()
                insertedItem = newItem
                modelContext.insert(newItem)
            }
            try modelContext.save()

            do {
                try stagedWrite?.commit()
            } catch {
                stagedWrite?.discard()
                if let insertedItem {
                    modelContext.delete(insertedItem)
                }
                if let item, let snapshot {
                    snapshot.restore(item)
                }
                try? modelContext.save()
                saveError = "The photo could not be saved. Please try again."
                return
            }

            dismiss()
        } catch {
            stagedWrite?.discard()
            if let insertedItem {
                modelContext.delete(insertedItem)
            }
            modelContext.rollback()
            if let item, let snapshot {
                snapshot.restore(item)
            }
            saveError = error.localizedDescription
        }
    }

    @MainActor
    private func persistSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                photoError = "The selected photo could not be loaded."
                return
            }
            guard let jpegData = ClosetItemPhotoPersistence.normalizedJPEGData(from: data) else {
                photoError = "The selected photo could not be read."
                return
            }
            draft.pendingPhotoJPEGData = jpegData
            photoError = nil
        } catch {
            photoError = "The selected photo could not be loaded."
        }
    }

    private func stageCameraImage(_ image: UIImage) {
        if let data = ClosetItemPhotoPersistence.jpegData(from: image) {
            draft.pendingPhotoJPEGData = data
            photoError = nil
        } else {
            photoError = "The captured photo could not be saved."
        }
    }
}

struct ClosetItemPhotoPersistence {
    static func jpegData(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.86)
    }

    static func normalizedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegData(from: image)
    }

    static func stageJPEGData(_ data: Data, id: UUID, imageStore: ImageStore) throws -> StagedPhotoWrite {
        try FileManager.default.createDirectory(
            at: imageStore.baseDirectory,
            withIntermediateDirectories: true
        )

        let stagingURL = imageStore.baseDirectory
            .appendingPathComponent("\(id.uuidString)-\(UUID().uuidString).staged.jpg")
        let finalURL = imageStore.baseDirectory
            .appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: stagingURL, options: [.atomic])

        return StagedPhotoWrite(stagingURL: stagingURL, finalURL: finalURL)
    }
}

struct StagedPhotoWrite {
    let stagingURL: URL
    let finalURL: URL

    func commit() throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: finalURL.path) {
            let backupURL = finalURL.deletingLastPathComponent()
                .appendingPathComponent("\(finalURL.deletingPathExtension().lastPathComponent)-backup-\(UUID().uuidString).jpg")
            try fileManager.moveItem(at: finalURL, to: backupURL)
            do {
                try fileManager.moveItem(at: stagingURL, to: finalURL)
                try? fileManager.removeItem(at: backupURL)
            } catch {
                try? fileManager.moveItem(at: backupURL, to: finalURL)
                throw error
            }
        } else {
            try fileManager.moveItem(at: stagingURL, to: finalURL)
        }
    }

    func discard() {
        try? FileManager.default.removeItem(at: stagingURL)
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct ClothingItemSnapshot {
    let photoLocalPath: String
    let typeRawValue: String
    let color: String
    let seasonRawValues: [String]
    let formalityLevel: Int
    let warmthLevel: Int
    let storageLocation: String
    let statusRawValue: String
    let notes: String
    let updatedAt: Date

    init(item: ClothingItem) {
        photoLocalPath = item.photoLocalPath
        typeRawValue = item.typeRawValue
        color = item.color
        seasonRawValues = item.seasonRawValues
        formalityLevel = item.formalityLevel
        warmthLevel = item.warmthLevel
        storageLocation = item.storageLocation
        statusRawValue = item.statusRawValue
        notes = item.notes
        updatedAt = item.updatedAt
    }

    func restore(_ item: ClothingItem) {
        item.photoLocalPath = photoLocalPath
        item.typeRawValue = typeRawValue
        item.color = color
        item.seasonRawValues = seasonRawValues
        item.formalityLevel = formalityLevel
        item.warmthLevel = warmthLevel
        item.storageLocation = storageLocation
        item.statusRawValue = statusRawValue
        item.notes = notes
        item.updatedAt = updatedAt
    }
}

#Preview {
    AddEditItemView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
