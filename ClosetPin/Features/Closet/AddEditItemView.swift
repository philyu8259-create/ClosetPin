import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddEditItemDraft {
    static let defaultFormalityLevel = 3
    static let defaultWarmthLevel = 3

    var itemID: UUID = UUID()
    var photoLocalPath: String = ""
    var originalPhotoLocalPath: String = ""
    var pendingPhotoJPEGData: Data?
    var pendingOriginalPhotoJPEGData: Data?
    var type: ClothingType = .top
    var color: String = ""
    var selectedSeasons: Set<SeasonTag> = []
    var formalityLevel: Int = defaultFormalityLevel
    var warmthLevel: Int = defaultWarmthLevel
    var storageLocation: String = ""
    var status: ClothingStatus = .available
    var notes: String = ""

    init(item: ClothingItem? = nil) {
        guard let item else { return }

        itemID = item.id
        photoLocalPath = item.photoLocalPath
        originalPhotoLocalPath = item.originalPhotoLocalPath
        type = item.type
        color = item.displayColor
        selectedSeasons = Set(item.seasons)
        formalityLevel = item.formalityLevel
        warmthLevel = item.warmthLevel
        storageLocation = item.displayStorageLocation
        status = item.status
        notes = item.notes
    }

    var validationMessages: [String] {
        var messages: [String] = []
        if normalized(color).isEmpty {
            messages.append(L10n.text("closet.validation.color_required"))
        }
        if normalized(photoLocalPath).isEmpty && pendingPhotoJPEGData == nil {
            messages.append(L10n.text("closet.validation.photo_required"))
        }
        if selectedSeasons.isEmpty {
            messages.append(L10n.text("closet.validation.season_required"))
        }
        if normalized(storageLocation).isEmpty {
            messages.append(L10n.text("closet.validation.storage_required"))
        }
        return messages
    }

    var canSave: Bool {
        validationMessages.isEmpty
    }

    var hasPhoto: Bool {
        normalized(photoLocalPath).isEmpty == false || pendingPhotoJPEGData != nil
    }

    var hasColor: Bool {
        normalized(color).isEmpty == false
    }

    var hasStorageLocation: Bool {
        normalized(storageLocation).isEmpty == false
    }

    var hasSeasonSelection: Bool {
        selectedSeasons.isEmpty == false
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
            originalPhotoLocalPath: originalPhotoLocalPath,
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
        item.originalPhotoLocalPath = originalPhotoLocalPath
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
    @Query(sort: \UserPreference.createdAt) private var preferences: [UserPreference]

    private let item: ClothingItem?
    private let imageStore: ImageStore
    private let photoTaggingPipeline: PhotoTaggingPipeline
    @State private var draft: AddEditItemDraft
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isCameraPresented = false
    @State private var saveError: String?
    @State private var photoError: String?
    @State private var photoPreview: PhotoPreviewSheet?
    @State private var photoSuggestion: ClothingPhotoTagSuggestion?
    @State private var showsOptionalDetails = false

    init(
        item: ClothingItem? = nil,
        imageStore: ImageStore = ImageStore(),
        photoTaggingPipeline: PhotoTaggingPipeline = .appDefault()
    ) {
        self.item = item
        self.imageStore = imageStore
        self.photoTaggingPipeline = photoTaggingPipeline
        _draft = State(initialValue: AddEditItemDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                editorialPhotoSection
                primaryDetailsSection
                optionalDetailsSection
            }
            .navigationTitle(item == nil ? L10n.text("closet.add_item") : L10n.text("closet.edit_item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.save")) {
                        save()
                    }
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("saveItemButton")
                }
            }
            .alert(L10n.text("closet.save_error_title"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(L10n.text("common.ok"), role: .cancel) {}
            } message: {
                Text(saveError ?? L10n.text("common.try_again"))
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
            .sheet(item: $photoPreview) { preview in
                PhotoPreviewSheetView(preview: preview)
            }
        }
    }

    private var editorialPhotoSection: some View {
        Section(L10n.text("closet.photo.editorial_title")) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if displayPreviewImage != nil || draft.hasPhoto {
                        WardrobePhotoThumbnail(
                            image: displayPreviewImage,
                            fallbackColor: ColorResolver.swatchColor(for: draft.color),
                            cornerRadius: DesignSystem.Radius.editorialHero
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 212)
                        .accessibilityIdentifier("photoPreview")
                    } else {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.editorialHero, style: .continuous)
                            .fill(DesignSystem.paper)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .overlay {
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "camera.macro")
                                        .font(.title2)
                                        .foregroundStyle(DesignSystem.secondaryInk)

                                    Text(L10n.text("closet.photo.help"))
                                        .font(.footnote)
                                        .foregroundStyle(DesignSystem.secondaryInk)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, DesignSystem.Spacing.xl)
                                }
                            }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            photoError = L10n.text("closet.photo.camera_unavailable")
                            return
                        }
                        isCameraPresented = true
                    } label: {
                        Label(L10n.text("closet.photo.take"), systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    .accessibilityIdentifier("takePhotoButton")

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(L10n.text("closet.photo.choose_library"), systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("chooseFromLibraryButton")
                }

                if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Text(L10n.text("closet.photo.camera_unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(L10n.text("closet.photo.editorial_help"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
            }

#if DEBUG
            if ProcessInfo.processInfo.environment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] == "1" {
                Button(L10n.text("closet.photo.use_test")) {
                    draft.pendingPhotoJPEGData = Data([0xFF, 0xD8, 0xFF, 0xD9])
                    draft.pendingOriginalPhotoJPEGData = draft.pendingPhotoJPEGData
                    photoError = nil
                }
                .accessibilityIdentifier("useTestPhotoButton")
            }
#endif

            if displayPreviewImage != nil {
                HStack {
                    Label(L10n.text("closet.photo.auto_cropped"), systemImage: "crop")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let originalPreviewImage {
                        Button {
                            photoPreview = PhotoPreviewSheet(
                                title: L10n.text("closet.photo.original"),
                                image: originalPreviewImage
                            )
                        } label: {
                            Label(L10n.text("closet.photo.view_original"), systemImage: "rectangle.expand.vertical")
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }

            if draft.pendingPhotoJPEGData != nil {
                Label(L10n.text("closet.photo.ready"), systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.accent)
            } else if !draft.photoLocalPath.isEmpty {
                Label(L10n.text("closet.photo.saved"), systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.accent)
            }

            if let photoSuggestion {
                Label(suggestionStatusText(for: photoSuggestion), systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("photoIntelligenceSuggestionStatus")
            }

            if let photoError {
                Label(photoError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var displayPreviewImage: UIImage? {
        if let data = draft.pendingPhotoJPEGData {
            return UIImage(data: data)
        }
        return WardrobePhoto.localImage(at: draft.photoLocalPath)
    }

    private var originalPreviewImage: UIImage? {
        if let data = draft.pendingOriginalPhotoJPEGData {
            return UIImage(data: data)
        }
        return WardrobePhoto.localImage(at: draft.originalPhotoLocalPath)
    }

    private var primaryDetailsSection: some View {
        Section(L10n.text("closet.ai_edit.section")) {
            EssentialsChecklistGrid(draft: draft)

            if let photoSuggestion {
                Label(suggestionStatusText(for: photoSuggestion), systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.premiumGold)
                    .accessibilityIdentifier("photoIntelligenceSuggestionStatus")
            }

            Picker(L10n.text("closet.type.label"), selection: $draft.type) {
                ForEach(ClothingType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField(L10n.text("closet.color.label"), text: $draft.color)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("itemColorField")

            TextField(L10n.text("closet.storage_location.label"), text: $draft.storageLocation)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("itemStorageField")

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(L10n.text("closet.seasons.section"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)

                seasonGrid
            }
            .padding(.vertical, 4)
        }
    }

    private var optionalDetailsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showsOptionalDetails) {
                Picker(L10n.text("closet.status.label"), selection: $draft.status) {
                    ForEach(ClothingStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                Stepper(L10n.string("closet.formality.format", arguments: draft.formalityLevel), value: $draft.formalityLevel, in: 1...5)
                Stepper(L10n.string("closet.warmth.format", arguments: draft.warmthLevel), value: $draft.warmthLevel, in: 1...5)

                TextField(L10n.text("closet.notes.placeholder"), text: $draft.notes, axis: .vertical)
                    .lineLimit(2...4)
            } label: {
                Text(L10n.text("closet.ai_edit.confirmation_section"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
            }
        }
    }

    private var seasonGrid: some View {
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
                    .background(isSelected ? DesignSystem.accent.opacity(0.14) : DesignSystem.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("seasonToggle_\(season.rawValue)")
                .accessibilityValue(isSelected ? L10n.text("closet.season.selected") : L10n.text("closet.season.not_selected"))
            }
        }
    }

    private func save() {
        guard draft.canSave else { return }

        var insertedItem: ClothingItem?
        let snapshot = item.map(ClothingItemSnapshot.init(item:))
        var stagedWrite: StagedPhotoDataWrite?

        do {
            var finalizedDraft = draft
            if let pendingPhotoJPEGData = draft.pendingPhotoJPEGData {
                let photoData = ProcessedClosetPhotoData(
                    displayJPEGData: pendingPhotoJPEGData,
                    originalJPEGData: draft.pendingOriginalPhotoJPEGData ?? pendingPhotoJPEGData
                )
                let write = try ClosetItemPhotoPersistence.stagePhotoData(
                    photoData,
                    id: draft.itemID,
                    imageStore: imageStore
                )
                stagedWrite = write
                finalizedDraft.photoLocalPath = write.display.finalURL.path
                finalizedDraft.originalPhotoLocalPath = write.original.finalURL.path
                finalizedDraft.pendingPhotoJPEGData = nil
                finalizedDraft.pendingOriginalPhotoJPEGData = nil
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
                saveError = L10n.text("closet.photo.save_failed")
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
                photoError = L10n.text("closet.photo.selected_load_failed")
                return
            }
            guard let photoData = ClosetItemPhotoPersistence.processedPhotoData(from: data) else {
                photoError = L10n.text("closet.photo.selected_read_failed")
                return
            }
            draft.pendingPhotoJPEGData = photoData.displayJPEGData
            draft.pendingOriginalPhotoJPEGData = photoData.originalJPEGData
            await applyPhotoIntelligenceIfAvailable(from: photoData.displayJPEGData)
            photoError = nil
        } catch {
            photoError = L10n.text("closet.photo.selected_load_failed")
        }
    }

    private func stageCameraImage(_ image: UIImage) {
        if let photoData = ClosetItemPhotoPersistence.processedPhotoData(from: image) {
            draft.pendingPhotoJPEGData = photoData.displayJPEGData
            draft.pendingOriginalPhotoJPEGData = photoData.originalJPEGData
            Task {
                await applyPhotoIntelligenceIfAvailable(from: photoData.displayJPEGData)
            }
            photoError = nil
        } else {
            photoError = L10n.text("closet.photo.captured_save_failed")
        }
    }

    @MainActor
    private func applyPhotoIntelligenceIfAvailable(from data: Data) async {
        guard let image = UIImage(data: data) else {
            photoSuggestion = nil
            return
        }

        guard let suggestion = await photoTaggingPipeline.suggestTags(
            for: image,
            allowsCloudRecognition: allowsCloudPhotoRecognition
        ) else {
            photoSuggestion = nil
            return
        }

        suggestion.apply(to: &draft)
        photoSuggestion = suggestion
    }

    private var allowsCloudPhotoRecognition: Bool {
        preferences.first?.cloudPhotoRecognitionEnabled ?? false
    }

    private func suggestionStatusText(for suggestion: ClothingPhotoTagSuggestion) -> String {
        L10n.string("closet.photo.ai_suggestion.format", arguments: suggestion.color, suggestion.type.displayName)
    }
}

private struct EssentialsChecklistGrid: View {
    let draft: AddEditItemDraft

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("closet.save_checklist.title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                EssentialsChecklistChip(title: L10n.text("closet.save_checklist.photo"), isComplete: draft.hasPhoto)
                EssentialsChecklistChip(title: L10n.text("closet.save_checklist.color"), isComplete: draft.hasColor)
                EssentialsChecklistChip(title: L10n.text("closet.save_checklist.season"), isComplete: draft.hasSeasonSelection)
                EssentialsChecklistChip(title: L10n.text("closet.save_checklist.storage"), isComplete: draft.hasStorageLocation)
            }
        }
    }
}

private struct EssentialsChecklistChip: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isComplete ? DesignSystem.accent : DesignSystem.secondaryInk)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(isComplete ? DesignSystem.accent.opacity(0.08) : DesignSystem.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isComplete ? DesignSystem.accent.opacity(0.18) : DesignSystem.border.opacity(0.4), lineWidth: 1)
        }
    }
}

struct ClosetItemPhotoPersistence {
    static func jpegData(from image: UIImage) -> Data? {
        normalizedImage(from: image).jpegData(compressionQuality: 0.86)
    }

    static func normalizedJPEGData(from data: Data) -> Data? {
        processedPhotoData(from: data)?.displayJPEGData
    }

    static func processedPhotoData(from data: Data) -> ProcessedClosetPhotoData? {
        guard let image = UIImage(data: data) else { return nil }
        return processedPhotoData(from: image)
    }

    static func processedPhotoData(from image: UIImage) -> ProcessedClosetPhotoData? {
        let originalImage = normalizedImage(from: image)
        guard let originalJPEGData = originalImage.jpegData(compressionQuality: 0.9) else { return nil }

        let displayImage = ClothingPhotoProcessor.autoCroppedDisplayImage(from: originalImage)
        guard let displayJPEGData = displayImage.jpegData(compressionQuality: 0.86) else { return nil }

        return ProcessedClosetPhotoData(
            displayJPEGData: displayJPEGData,
            originalJPEGData: originalJPEGData
        )
    }

    static func stageJPEGData(_ data: Data, id: UUID, imageStore: ImageStore) throws -> StagedPhotoWrite {
        try stageJPEGData(
            data,
            stagingDirectory: imageStore.baseDirectory,
            finalURL: imageStore.baseDirectory.appendingPathComponent("\(id.uuidString).jpg")
        )
    }

    static func stagePhotoData(_ data: ProcessedClosetPhotoData, id: UUID, imageStore: ImageStore) throws -> StagedPhotoDataWrite {
        let displayWrite = try stageJPEGData(data.displayJPEGData, id: id, imageStore: imageStore)
        do {
            let originalsDirectory = imageStore.baseDirectory.appendingPathComponent("Originals", isDirectory: true)
            let originalWrite = try stageJPEGData(
                data.originalJPEGData,
                stagingDirectory: originalsDirectory,
                finalURL: originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")
            )
            return StagedPhotoDataWrite(display: displayWrite, original: originalWrite)
        } catch {
            displayWrite.discard()
            throw error
        }
    }

    static func removeLocalPhotos(for item: ClothingItem) {
        removePhoto(at: item.photoLocalPath)
        removePhoto(at: item.originalPhotoLocalPath)
    }

    private static func stageJPEGData(_ data: Data, stagingDirectory: URL, finalURL: URL) throws -> StagedPhotoWrite {
        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )

        let stagingURL = stagingDirectory
            .appendingPathComponent("\(finalURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).staged.jpg")
        try data.write(to: stagingURL, options: [.atomic])

        return StagedPhotoWrite(stagingURL: stagingURL, finalURL: finalURL)
    }

    private static func normalizedImage(from image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func removePhoto(at path: String) {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              FileManager.default.fileExists(atPath: path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}

struct ProcessedClosetPhotoData {
    let displayJPEGData: Data
    let originalJPEGData: Data
}

struct ClothingPhotoProcessor {
    static func autoCroppedDisplayImage(from image: UIImage) -> UIImage {
        guard let cropRect = foregroundCropRect(in: image) else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: cropRect.size, format: format).image { _ in
            image.draw(
                in: CGRect(
                    x: -cropRect.origin.x,
                    y: -cropRect.origin.y,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }

    private static func foregroundCropRect(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 2, height > 2 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let background = averageCornerColor(in: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foregroundCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 20 else { continue }

                let difference = abs(Int(pixels[offset]) - background.red)
                    + abs(Int(pixels[offset + 1]) - background.green)
                    + abs(Int(pixels[offset + 2]) - background.blue)
                if difference > 75 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                    foregroundCount += 1
                }
            }
        }

        guard foregroundCount > max(16, (width * height) / 300) else { return nil }

        let cropWidth = maxX - minX + 1
        let cropHeight = maxY - minY + 1
        let sourceArea = width * height
        let cropArea = cropWidth * cropHeight
        guard cropArea < Int(Double(sourceArea) * 0.92) else { return nil }

        let paddingX = max(2, Int(Double(cropWidth) * 0.14))
        let paddingY = max(2, Int(Double(cropHeight) * 0.14))
        let paddedMinX = max(0, minX - paddingX)
        let paddedMinY = max(0, minY - paddingY)
        let paddedMaxX = min(width - 1, maxX + paddingX)
        let paddedMaxY = min(height - 1, maxY + paddingY)

        let scaleX = image.size.width / CGFloat(width)
        let scaleY = image.size.height / CGFloat(height)
        return CGRect(
            x: CGFloat(paddedMinX) * scaleX,
            y: CGFloat(paddedMinY) * scaleY,
            width: CGFloat(paddedMaxX - paddedMinX + 1) * scaleX,
            height: CGFloat(paddedMaxY - paddedMinY + 1) * scaleY
        )
    }

    private static func averageCornerColor(in pixels: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> (red: Int, green: Int, blue: Int) {
        let sampleSize = max(1, min(width, height, 12))
        let origins = [
            (x: 0, y: 0),
            (x: width - sampleSize, y: 0),
            (x: 0, y: height - sampleSize),
            (x: width - sampleSize, y: height - sampleSize)
        ]
        var red = 0
        var green = 0
        var blue = 0
        var count = 0

        for origin in origins {
            for y in origin.y..<(origin.y + sampleSize) {
                for x in origin.x..<(origin.x + sampleSize) {
                    let offset = y * bytesPerRow + x * 4
                    red += Int(pixels[offset])
                    green += Int(pixels[offset + 1])
                    blue += Int(pixels[offset + 2])
                    count += 1
                }
            }
        }

        return (red / count, green / count, blue / count)
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

struct StagedPhotoDataWrite {
    let display: StagedPhotoWrite
    let original: StagedPhotoWrite

    func commit() throws {
        try original.commit()
        try display.commit()
    }

    func discard() {
        display.discard()
        original.discard()
    }
}

struct PhotoPreviewSheet: Identifiable {
    let id = UUID()
    let title: String
    let image: UIImage
}

struct PhotoPreviewSheetView: View {
    let preview: PhotoPreviewSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.background.ignoresSafeArea()

                Image(uiImage: preview.image)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            }
            .navigationTitle(preview.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.ok")) {
                        dismiss()
                    }
                }
            }
        }
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
    let originalPhotoLocalPath: String
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
        originalPhotoLocalPath = item.originalPhotoLocalPath
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
        item.originalPhotoLocalPath = originalPhotoLocalPath
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
        .modelContainer(for: [ClothingItem.self, UserPreference.self], inMemory: true)
}
