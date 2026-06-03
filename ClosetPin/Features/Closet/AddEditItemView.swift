import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum PhotoPreviewMode: Hashable {
    case display
    case original
}

private enum PhotoPreparationState: Equatable {
    case idle
    case preparing
    case analyzing

    var isBusy: Bool {
        self != .idle
    }
}

private enum PhotoSuggestionField: CaseIterable, Hashable {
    case type
    case color
    case seasons
    case formality
    case warmth
}

private enum FormalityLevelLabel: Int, CaseIterable {
    case lowest = 1
    case low = 2
    case neutral = 3
    case high = 4
    case highest = 5

    var title: String {
        switch self {
        case .lowest:
            L10n.text("closet.formality.level_1")
        case .low:
            L10n.text("closet.formality.level_2")
        case .neutral:
            L10n.text("closet.formality.level_3")
        case .high:
            L10n.text("closet.formality.level_4")
        case .highest:
            L10n.text("closet.formality.level_5")
        }
    }
}

private enum WarmthLevelLabel: Int, CaseIterable {
    case lowest = 1
    case low = 2
    case neutral = 3
    case high = 4
    case highest = 5

    var title: String {
        switch self {
        case .lowest:
            L10n.text("closet.warmth.level_1")
        case .low:
            L10n.text("closet.warmth.level_2")
        case .neutral:
            L10n.text("closet.warmth.level_3")
        case .high:
            L10n.text("closet.warmth.level_4")
        case .highest:
            L10n.text("closet.warmth.level_5")
        }
    }
}

struct AddEditItemDraft {
    static let defaultFormalityLevel = 3
    static let defaultWarmthLevel = 3

    enum SeasonSelectionSource {
        case systemDate
        case photoSuggestion
        case manual
    }

    var itemID: UUID = UUID()
    var photoLocalPath: String = ""
    var originalPhotoLocalPath: String = ""
    var pendingPhotoJPEGData: Data?
    var pendingOriginalPhotoJPEGData: Data?
    var type: ClothingType = .top
    var color: String = ""
    var selectedSeasons: Set<SeasonTag> = []
    var seasonSelectionSource: SeasonSelectionSource = .systemDate
    var formalityLevel: Int = defaultFormalityLevel
    var warmthLevel: Int = defaultWarmthLevel
    var storageLocation: String = ""
    var status: ClothingStatus = .available
    var notes: String = ""

    init(item: ClothingItem? = nil, initialType: ClothingType = .top) {
        guard let item else {
            type = initialType
            selectAutomaticCurrentSeason()
            return
        }

        itemID = item.id
        photoLocalPath = item.photoLocalPath
        originalPhotoLocalPath = item.originalPhotoLocalPath
        type = item.type
        color = item.displayColor
        selectedSeasons = Set(item.seasons)
        seasonSelectionSource = .manual
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
        seasonSelectionSource = .manual
    }

    mutating func selectCurrentSeason(date: Date = Date(), calendar: Calendar = .current) {
        selectedSeasons = [SeasonResolver.currentSeason(date: date, calendar: calendar)]
        seasonSelectionSource = .manual
    }

    mutating func selectAutomaticCurrentSeason(date: Date = Date(), calendar: Calendar = .current) {
        selectedSeasons = [SeasonResolver.currentSeason(date: date, calendar: calendar)]
        seasonSelectionSource = .systemDate
    }

    mutating func selectYearRound() {
        selectedSeasons = Set(SeasonTag.allCases)
        seasonSelectionSource = .manual
    }

    mutating func applyPhotoSuggestedSeasons(_ seasons: Set<SeasonTag>) {
        guard !seasons.isEmpty else { return }
        selectedSeasons = seasons
        seasonSelectionSource = .photoSuggestion
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
    @State private var photoTaggingOutcome: PhotoTaggingOutcome?
    @State private var pendingPhotoSuggestion: ClothingPhotoTagSuggestion?
    @State private var suggestionNeedsReview = false
    @State private var didApplyLatestSuggestion = false
    @State private var photoPreviewMode: PhotoPreviewMode = .display
    @State private var photoPreparationState: PhotoPreparationState = .idle
    @State private var showPostSaveGuide = false
    @State private var postSaveGuidance: String?
    @State private var showsOptionalDetails = false
    @State private var showsSeasonChooser = false

    init(
        item: ClothingItem? = nil,
        imageStore: ImageStore = ImageStore(),
        photoTaggingPipeline: PhotoTaggingPipeline = .appDefault(),
        initialType: ClothingType = .top
    ) {
        self.item = item
        self.imageStore = imageStore
        self.photoTaggingPipeline = photoTaggingPipeline
        _draft = State(initialValue: AddEditItemDraft(item: item, initialType: initialType))
    }

    var body: some View {
        NavigationStack {
            Form {
                editorialPhotoSection
                primaryDetailsSection
                optionalDetailsSection
                if showPostSaveGuide {
                    postSaveGuidanceSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.background)
            .tint(DesignSystem.accent)
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
                    .disabled(photoPreparationState.isBusy || !draft.canSave)
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
                    if let previewImage {
                        WardrobePhotoThumbnail(
                            image: previewImage,
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
                        openCameraForPhoto()
                    } label: {
                        Label(L10n.text("closet.photo.take"), systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(photoPreparationState.isBusy || !UIImagePickerController.isSourceTypeAvailable(.camera))
                    .accessibilityIdentifier("takePhotoButton")

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(L10n.text("closet.photo.choose_library"), systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(photoPreparationState.isBusy)
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
                Text(L10n.text("closet.photo.post_capture_help"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.accent)
                    .fixedSize(horizontal: false, vertical: true)

                if photoPreparationState.isBusy {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(DesignSystem.accent)

                        Text(photoPreparationMessage)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                    .accessibilityIdentifier("photoProcessingStatus")
                }
            }

            if draft.hasPhoto || displayPreviewImage != nil {
                Divider()
                    .padding(.vertical, 4)

                HStack(alignment: .top) {
                    Label(L10n.text("closet.photo.preview"), systemImage: "photo.on.rectangle")
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.secondaryInk)

                    Spacer()

                    if originalPreviewImage != nil {
                        Picker(
                            L10n.text("closet.photo.preview_mode"),
                            selection: $photoPreviewMode
                        ) {
                            Text(L10n.text("closet.photo.preview.display")).tag(PhotoPreviewMode.display)
                            Text(L10n.text("closet.photo.preview.original")).tag(PhotoPreviewMode.original)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 212)
                    } else {
                        HStack(spacing: 8) {
                            Text(L10n.text("closet.photo.preview.disabled_placeholder"))
                                .font(.caption)
                                .foregroundStyle(DesignSystem.secondaryInk)
                        }
                    }
                }

                if originalPreviewImage == nil {
                    Label(L10n.text("closet.photo.original_not_ready"), systemImage: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

#if DEBUG
            if ProcessInfo.processInfo.environment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] == "1" {
                Button(L10n.text("closet.photo.use_test")) {
                    draft.pendingPhotoJPEGData = Data([0xFF, 0xD8, 0xFF, 0xD9])
                    draft.pendingOriginalPhotoJPEGData = draft.pendingPhotoJPEGData
                    photoTaggingOutcome = debugPhotoTaggingOutcome
                    pendingPhotoSuggestion = debugPhotoTaggingOutcome.suggestion
                    didApplyLatestSuggestion = false
                    suggestionNeedsReview = true
                    photoPreviewMode = .display
                    showPostSaveGuide = false
                    postSaveGuidance = nil
                    photoError = nil
                }
                .accessibilityIdentifier("useTestPhotoButton")
            }
#endif

            if previewImage != nil {
                HStack {
                    Button {
                        openCameraForPhoto()
                    } label: {
                        Label(L10n.text("closet.photo.retake"), systemImage: "camera")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(photoPreparationState.isBusy)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(L10n.text("closet.photo.replace"), systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote.weight(.semibold))
                            .accessibilityIdentifier("photoReplaceButton")
                    }
                    .buttonStyle(.bordered)
                    .disabled(photoPreparationState.isBusy)
                    .accessibilityIdentifier("photoReplaceButton")

                    Spacer()

                    Button {
                    } label: {
                        Label(L10n.text("closet.photo.adjust_crop"), systemImage: "crop")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(true)
                    .buttonStyle(.borderless)
                }

                if photoPreviewMode == .display {
                    Label(L10n.text("closet.photo.auto_cropped"), systemImage: "crop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            if let photoTaggingOutcome {
                if suggestionNeedsReview {
                    photoSuggestionReviewCard(for: photoTaggingOutcome)
                } else if didApplyLatestSuggestion {
                    Label(
                        L10n.string("closet.photo.ai_suggestion.auto_applied.format", arguments: photoTaggingOutcome.suggestion.type.displayName),
                        systemImage: suggestionStatusIcon(for: photoTaggingOutcome)
                    )
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .accessibilityIdentifier("photoAutoAppliedTag")
                }
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

    private var previewImage: UIImage? {
        switch photoPreviewMode {
        case .display:
            return displayPreviewImage
        case .original:
            if let originalPreviewImage {
                return originalPreviewImage
            }
            return displayPreviewImage
        }
    }

    private var postSaveMessage: String {
        if let guidance = postSaveGuidance {
            return guidance
        }

        if item == nil {
            return L10n.text("closet.post_save.continue_note")
        }
        return L10n.text("closet.post_save.item_saved")
    }

    private var photoPreparationMessage: String {
        switch photoPreparationState {
        case .idle:
            ""
        case .preparing:
            L10n.text("closet.photo.processing.prepare")
        case .analyzing:
            L10n.text("closet.photo.processing.analyze")
        }
    }

#if DEBUG
    private var debugPhotoTaggingOutcome: PhotoTaggingOutcome {
        PhotoTaggingOutcome(
            suggestion: ClothingPhotoTagSuggestion(
                type: .top,
                color: "Ivory",
                seasons: [SeasonResolver.currentSeason()],
                formalityLevel: 3,
                warmthLevel: 2,
                confidence: 0.82,
                source: .localHeuristic
            ),
            delivery: .localOnly
        )
    }
#endif

    private var primaryDetailsSection: some View {
        Section(L10n.text("closet.ai_edit.section")) {
            EssentialsChecklistGrid(draft: draft)

            Text(L10n.text("closet.ai_edit.helper"))
                .font(.caption)
                .foregroundStyle(DesignSystem.secondaryInk)
                .accessibilityIdentifier("addItemFlowGuide")

            Picker(L10n.text("closet.type.label"), selection: $draft.type) {
                ForEach(ClothingType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField(L10n.text("closet.color.label"), text: $draft.color)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("itemColorField")

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(L10n.text("closet.seasons.section"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)

                ClosetSeasonAutoCard(
                    selectedSeasons: draft.selectedSeasons,
                    selectionSource: draft.seasonSelectionSource,
                    isExpanded: $showsSeasonChooser
                )

                if showsSeasonChooser {
                    SeasonShortcutRow(
                        selectCurrentSeason: { draft.selectCurrentSeason() },
                        selectYearRound: { draft.selectYearRound() }
                    )

                    seasonGrid
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var optionalDetailsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showsOptionalDetails) {
                TextField(L10n.text("closet.storage_location.label"), text: $draft.storageLocation)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("itemStorageField")

                StatusSelectionGrid(selection: $draft.status)

                FormalityLevelControl(
                    title: L10n.text("closet.formality.label"),
                    options: FormalityLevelLabel.allCases,
                    selected: $draft.formalityLevel,
                    selectedTitle: L10n.string("closet.formality.preview.format", arguments: formalityLabel(for: draft.formalityLevel))
                )

                WarmthLevelControl(
                    title: L10n.text("closet.warmth.label"),
                    options: WarmthLevelLabel.allCases,
                    selected: $draft.warmthLevel,
                    selectedTitle: L10n.string("closet.warmth.preview.format", arguments: warmthLabel(for: draft.warmthLevel))
                )

                TextField(L10n.text("closet.notes.placeholder"), text: $draft.notes, axis: .vertical)
                    .lineLimit(2...4)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("closet.ai_edit.confirmation_section"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)

                    Text(L10n.text("closet.optional_details.helper"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.secondaryInk)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("optionalDetailsDisclosure")
            }
        }
    }

    private var postSaveGuidanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text(L10n.text("closet.post_save.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(postSaveMessage)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)

                if item == nil {
                    Button(L10n.text("closet.post_save.continue")) {
                        resetDraftForNextAdd()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("postSaveContinueAddingButton")

                    Button(L10n.text("closet.post_save.generate_today")) {
                        postSaveGuidance = L10n.text("closet.post_save.generate_hint")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("postSaveGenerateTodayButton")
                }

                Button(L10n.text("closet.post_save.view_closet")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("postSaveViewClosetButton")
            }
            .padding(.vertical, 4)
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

            if item == nil {
                showPostSaveGuide = true
                postSaveGuidance = nil
                suggestionNeedsReview = false
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

    private func resetDraftForNextAdd() {
        draft = AddEditItemDraft(initialType: .top)
        selectedPhotoItem = nil
        photoTaggingOutcome = nil
        pendingPhotoSuggestion = nil
        suggestionNeedsReview = false
        didApplyLatestSuggestion = false
        photoError = nil
        postSaveGuidance = nil
        showPostSaveGuide = false
        photoPreview = nil
        photoPreviewMode = .display
        photoPreparationState = .idle
        showsOptionalDetails = false
        showsSeasonChooser = false
    }

    @MainActor
    private func persistSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            photoPreparationState = .preparing
            clearPendingSuggestionReview()
            guard let data = try await item.loadTransferable(type: Data.self) else {
                photoError = L10n.text("closet.photo.selected_load_failed")
                photoPreparationState = .idle
                return
            }
            guard let photoData = await prepareProcessedPhotoData(from: data) else {
                photoError = L10n.text("closet.photo.selected_read_failed")
                photoPreparationState = .idle
                return
            }
            draft.pendingPhotoJPEGData = photoData.displayJPEGData
            draft.pendingOriginalPhotoJPEGData = photoData.originalJPEGData
            await applyPhotoIntelligenceIfAvailable(from: photoData.displayJPEGData)
            photoPreviewMode = .display
            showPostSaveGuide = false
            postSaveGuidance = nil
            photoError = nil
            selectedPhotoItem = nil
        } catch {
            photoError = L10n.text("closet.photo.selected_load_failed")
            photoPreparationState = .idle
            selectedPhotoItem = nil
        }
    }

    private func stageCameraImage(_ image: UIImage) {
        photoPreparationState = .preparing
        clearPendingSuggestionReview()

        guard let rawJPEGData = ClosetItemPhotoPersistence.jpegData(from: image) else {
            photoError = L10n.text("closet.photo.captured_save_failed")
            photoPreparationState = .idle
            return
        }

        Task {
            if let photoData = await prepareProcessedPhotoData(from: rawJPEGData) {
                draft.pendingPhotoJPEGData = photoData.displayJPEGData
                draft.pendingOriginalPhotoJPEGData = photoData.originalJPEGData
                await applyPhotoIntelligenceIfAvailable(from: photoData.displayJPEGData)
                photoPreviewMode = .display
                showPostSaveGuide = false
                postSaveGuidance = nil
                photoError = nil
            } else {
                photoError = L10n.text("closet.photo.captured_save_failed")
                photoPreparationState = .idle
            }
        }
    }

    private func prepareProcessedPhotoData(from data: Data) async -> ProcessedClosetPhotoData? {
        await Task.detached(priority: .userInitiated) {
            ClosetItemPhotoPersistence.processedPhotoData(from: data)
        }.value
    }

    @MainActor
    private func applyPhotoIntelligenceIfAvailable(from data: Data) async {
        guard let image = UIImage(data: data) else {
            photoTaggingOutcome = nil
            pendingPhotoSuggestion = nil
            suggestionNeedsReview = false
            didApplyLatestSuggestion = false
            photoPreparationState = .idle
            return
        }

        photoPreparationState = .analyzing
        guard let outcome = await photoTaggingPipeline.suggestionOutcome(
            for: image,
            allowsCloudRecognition: allowsCloudPhotoRecognition
        ) else {
            photoTaggingOutcome = nil
            pendingPhotoSuggestion = nil
            suggestionNeedsReview = false
            didApplyLatestSuggestion = false
            photoPreparationState = .idle
            return
        }

        photoTaggingOutcome = outcome
        pendingPhotoSuggestion = outcome.suggestion
        suggestionNeedsReview = true
        didApplyLatestSuggestion = false
        photoPreparationState = .idle
    }

    private func openCameraForPhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            photoError = L10n.text("closet.photo.camera_unavailable")
            return
        }
        isCameraPresented = true
    }

    private func applyPendingPhotoSuggestion() {
        guard let pendingPhotoSuggestion else { return }
        let fields = suggestedChanges(for: pendingPhotoSuggestion).map(\.field)
        applyPendingPhotoSuggestion(fields: Set(fields))
    }

    private func applyPendingPhotoSuggestion(fields: Set<PhotoSuggestionField>) {
        guard let pendingPhotoSuggestion else { return }
        guard !fields.isEmpty else {
            self.pendingPhotoSuggestion = nil
            suggestionNeedsReview = false
            didApplyLatestSuggestion = true
            return
        }

        if fields.contains(.type) {
            draft.type = pendingPhotoSuggestion.type
        }
        if fields.contains(.color) {
            draft.color = pendingPhotoSuggestion.color
        }
        if fields.contains(.seasons) {
            draft.applyPhotoSuggestedSeasons(pendingPhotoSuggestion.seasons)
        }
        if fields.contains(.formality) {
            draft.formalityLevel = pendingPhotoSuggestion.formalityLevel
        }
        if fields.contains(.warmth) {
            draft.warmthLevel = pendingPhotoSuggestion.warmthLevel
        }

        self.pendingPhotoSuggestion = nil
        suggestionNeedsReview = false
        didApplyLatestSuggestion = true
    }

    private func dismissPendingPhotoSuggestionForManualEdit() {
        pendingPhotoSuggestion = nil
        suggestionNeedsReview = false
        didApplyLatestSuggestion = false
        showsOptionalDetails = true
    }

    private func clearPendingSuggestionReview() {
        photoTaggingOutcome = nil
        pendingPhotoSuggestion = nil
        suggestionNeedsReview = false
        didApplyLatestSuggestion = false
    }

    private func photoSuggestionReviewCard(for outcome: PhotoTaggingOutcome) -> some View {
        let changes = suggestedChanges(for: outcome.suggestion)

        return LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(L10n.text("closet.photo.ai_suggestion.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .accessibilityIdentifier("photoSuggestionReviewTitle")

                Text(suggestionStatusText(for: outcome))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)

                Divider()

                if changes.isEmpty {
                    Label(L10n.text("closet.photo.ai_suggestion.no_changes"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.accent)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(changes, id: \.field) { change in
                            suggestionRow(label: change.label, value: change.value)
                        }
                    }
                }

                if suggestionNeedsReview {
                    Text(L10n.text("closet.photo.ai_suggestion.footer"))
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Button(L10n.text("closet.photo.ai_suggestion.use")) {
                            applyPendingPhotoSuggestion()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.accent)
                        .accessibilityIdentifier("photoSuggestionUseButton")

                        Spacer()

                        Button(L10n.text("closet.photo.ai_suggestion.edit_manual")) {
                            dismissPendingPhotoSuggestionForManualEdit()
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("photoSuggestionEditManualButton")
                    }

                    if !changes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(changes, id: \.field) { change in
                                    Button(change.partialActionTitle) {
                                        applyPendingPhotoSuggestion(fields: [change.field])
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(DesignSystem.accent)
                                    .accessibilityIdentifier("photoSuggestionApply_\(change.accessibilitySuffix)")
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }
        }
    }

    private func suggestedChanges(for suggestion: ClothingPhotoTagSuggestion) -> [PhotoSuggestionChange] {
        var changes: [PhotoSuggestionChange] = []

        if draft.type == .top, draft.type != suggestion.type {
            changes.append(.type(value: suggestion.type.displayName))
        }

        let currentColor = draft.color.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedColor = suggestion.color.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentColor.isEmpty, !suggestedColor.isEmpty {
            changes.append(.color(value: suggestedColor))
        }

        if draft.selectedSeasons.isEmpty || draft.seasonSelectionSource == .systemDate {
            let suggestedSeasons = SeasonTag.allCases.filter { suggestion.seasons.contains($0) }
            if Set(suggestedSeasons) != draft.selectedSeasons, !suggestedSeasons.isEmpty {
                changes.append(.seasons(value: suggestedSeasons.map(\.displayName).joined(separator: " · ")))
            }
        }

        if draft.formalityLevel == AddEditItemDraft.defaultFormalityLevel,
           draft.formalityLevel != suggestion.formalityLevel {
            changes.append(.formality(value: formalityLabel(for: suggestion.formalityLevel)))
        }

        if draft.warmthLevel == AddEditItemDraft.defaultWarmthLevel,
           draft.warmthLevel != suggestion.warmthLevel {
            changes.append(.warmth(value: warmthLabel(for: suggestion.warmthLevel)))
        }

        return changes
    }

    private func suggestionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value.isEmpty ? L10n.text("closet.photo.ai_suggestion.unknown") : value)
                .font(.caption)
                .foregroundStyle(DesignSystem.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private struct PhotoSuggestionChange: Hashable {
        let field: PhotoSuggestionField
        let label: String
        let value: String
        let partialActionTitle: String
        let accessibilitySuffix: String

        static func type(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .type,
                label: L10n.text("closet.photo.ai_suggestion.type"),
                value: value,
                partialActionTitle: L10n.text("closet.photo.ai_suggestion.apply_type"),
                accessibilitySuffix: "type"
            )
        }

        static func color(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .color,
                label: L10n.text("closet.photo.ai_suggestion.color"),
                value: value,
                partialActionTitle: L10n.text("closet.photo.ai_suggestion.apply_color"),
                accessibilitySuffix: "color"
            )
        }

        static func seasons(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .seasons,
                label: L10n.text("closet.photo.ai_suggestion.seasons"),
                value: value,
                partialActionTitle: L10n.text("closet.photo.ai_suggestion.apply_seasons"),
                accessibilitySuffix: "seasons"
            )
        }

        static func formality(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .formality,
                label: L10n.text("closet.photo.ai_suggestion.formality"),
                value: value,
                partialActionTitle: L10n.text("closet.photo.ai_suggestion.apply_formality"),
                accessibilitySuffix: "formality"
            )
        }

        static func warmth(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .warmth,
                label: L10n.text("closet.photo.ai_suggestion.warmth"),
                value: value,
                partialActionTitle: L10n.text("closet.photo.ai_suggestion.apply_warmth"),
                accessibilitySuffix: "warmth"
            )
        }
    }

    private var allowsCloudPhotoRecognition: Bool {
        preferences.first?.cloudPhotoRecognitionEnabled ?? false
    }

    private func suggestionStatusText(for outcome: PhotoTaggingOutcome) -> String {
        let suggestion = outcome.suggestion
        let suggestionSummary = [suggestion.color, suggestion.type.displayName]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
        let key = switch outcome.delivery {
        case .localOnly:
            "closet.photo.ai_suggestion.local.format"
        case .remoteAI:
            "closet.photo.ai_suggestion.cloud.format"
        case .localAfterCloudUnavailable:
            "closet.photo.ai_suggestion.cloud_fallback.format"
        }
        return L10n.string(key, arguments: suggestionSummary)
    }

    private func suggestionStatusIcon(for outcome: PhotoTaggingOutcome) -> String {
        switch outcome.delivery {
        case .localOnly:
            "wand.and.stars"
        case .remoteAI:
            "sparkles"
        case .localAfterCloudUnavailable:
            "icloud"
        }
    }
}

private struct ClosetSeasonAutoCard: View {
    let selectedSeasons: Set<SeasonTag>
    let selectionSource: AddEditItemDraft.SeasonSelectionSource
    @Binding var isExpanded: Bool

    private var seasonSummary: String {
        let seasons = SeasonTag.allCases
            .filter { selectedSeasons.contains($0) }
            .map(\.displayName)

        guard !seasons.isEmpty else {
            return L10n.text("closet.season.none")
        }
        return seasons.joined(separator: ", ")
    }

    private var summaryText: String {
        switch selectionSource {
        case .systemDate:
            return L10n.string("closet.season.auto.current.format", arguments: seasonSummary)
        case .photoSuggestion:
            return L10n.string("closet.season.auto.photo.format", arguments: seasonSummary)
        case .manual:
            return seasonSummary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignSystem.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("closet.season.auto.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
            }

            Spacer(minLength: DesignSystem.Spacing.sm)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(L10n.text("closet.season.change"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(DesignSystem.accent.opacity(0.1))
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("closetSeasonChangeButton")
        }
        .padding(12)
        .background(DesignSystem.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignSystem.border.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SeasonShortcutRow: View {
    let selectCurrentSeason: () -> Void
    let selectYearRound: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            SeasonShortcutButton(
                title: L10n.text("closet.season.current_shortcut"),
                systemImage: "calendar.badge.clock",
                accessibilityIdentifier: "seasonShortcut_current",
                action: selectCurrentSeason
            )

            SeasonShortcutButton(
                title: L10n.text("closet.season.year_round_shortcut"),
                systemImage: "arrow.triangle.2.circlepath",
                accessibilityIdentifier: "seasonShortcut_yearRound",
                action: selectYearRound
            )
        }
    }
}

private struct SeasonShortcutButton: View {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(DesignSystem.accent)
                .background(DesignSystem.accent.opacity(0.1))
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct EssentialsChecklistGrid: View {
    let draft: AddEditItemDraft

    private var missingTitles: [String] {
        var titles: [String] = []

        if !draft.hasPhoto {
            titles.append(L10n.text("closet.save_checklist.photo"))
        }
        if !draft.hasColor {
            titles.append(L10n.text("closet.save_checklist.color"))
        }
        if !draft.hasSeasonSelection {
            titles.append(L10n.text("closet.save_checklist.season"))
        }

        return titles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if missingTitles.isEmpty {
                Label(L10n.text("closet.save_checklist.ready"), systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text(L10n.text("closet.save_checklist.title"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.secondaryInk)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(missingTitles, id: \.self) { title in
                        EssentialsChecklistChip(title: title, isComplete: false)
                    }
                }

                Text(L10n.text("closet.save_checklist.action_hint"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .padding(.top, 2)
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

private struct StatusSelectionGrid: View {
    @Binding var selection: ClothingStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("closet.status.label"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.secondaryInk)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(ClothingStatus.allCases) { status in
                    let isSelected = selection == status
                    Button {
                        selection = status
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: status.systemImage)
                                .font(.subheadline.weight(.semibold))
                            Text(status.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? .white : DesignSystem.ink)
                        .background(isSelected ? statusColor(for: status) : DesignSystem.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(statusColor(for: status).opacity(isSelected ? 0.16 : 0.24), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("statusOption_\(status.rawValue)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: ClothingStatus) -> Color {
        DesignSystem.statusColor(for: status)
    }
}

private struct FormalityLevelControl: View {
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

private struct WarmthLevelControl: View {
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

private func formalityLabel(for value: Int) -> String {
    switch max(1, min(5, value)) {
    case 1:
        return L10n.text("closet.formality.level_1")
    case 2:
        return L10n.text("closet.formality.level_2")
    case 3:
        return L10n.text("closet.formality.level_3")
    case 4:
        return L10n.text("closet.formality.level_4")
    default:
        return L10n.text("closet.formality.level_5")
    }
}

private func warmthLabel(for value: Int) -> String {
    switch max(1, min(5, value)) {
    case 1:
        return L10n.text("closet.warmth.level_1")
    case 2:
        return L10n.text("closet.warmth.level_2")
    case 3:
        return L10n.text("closet.warmth.level_3")
    case 4:
        return L10n.text("closet.warmth.level_4")
    default:
        return L10n.text("closet.warmth.level_5")
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
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async {
                dismiss()
            }
            return picker
        }
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
