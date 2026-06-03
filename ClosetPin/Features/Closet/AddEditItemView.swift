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
                    .accessibilityIdentifier("photoAiHelpText")

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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if missingPrimaryRequirements.isEmpty {
                    Label(L10n.text("closet.save_checklist.ready"), systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .accessibilityIdentifier("addItemFlowGuide")
                } else {
                    Text(L10n.text("closet.save_checklist.title"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignSystem.secondaryInk)
                }

                if missingPrimaryRequirements.isEmpty == false {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(missingPrimaryRequirements, id: \.self) { requirement in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(DesignSystem.secondaryInk)
                                    .font(.caption2)
                                Text(requirement)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DesignSystem.ink)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(DesignSystem.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                Text(L10n.text("closet.ai_edit.helper"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
            }

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

    private var missingPrimaryRequirements: [String] {
        var requirements: [String] = []
        if !draft.hasPhoto {
            requirements.append(L10n.text("closet.save_checklist.photo"))
        }
        if !draft.hasColor {
            requirements.append(L10n.text("closet.save_checklist.color"))
        }
        if !draft.hasSeasonSelection {
            requirements.append(L10n.text("closet.save_checklist.season"))
        }
        return requirements
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
        applyPendingPhotoSuggestion(fields: suggestedChangeFields(for: pendingPhotoSuggestion))
    }

    private func applyPendingPhotoSuggestion(fields: Set<PhotoSuggestionField>) {
        guard let suggestion = pendingPhotoSuggestion else { return }
        guard fields.isEmpty == false else {
            self.pendingPhotoSuggestion = nil
            suggestionNeedsReview = false
            didApplyLatestSuggestion = false
            return
        }

        if fields.contains(.type) {
            draft.type = suggestion.type
        }
        if fields.contains(.color) {
            draft.color = suggestion.color
        }
        if fields.contains(.seasons) {
            draft.applyPhotoSuggestedSeasons(suggestion.seasons)
        }
        if fields.contains(.formality) {
            draft.formalityLevel = suggestion.formalityLevel
        }
        if fields.contains(.warmth) {
            draft.warmthLevel = suggestion.warmthLevel
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

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Button(L10n.text("closet.photo.ai_suggestion.use")) {
                                applyPendingPhotoSuggestion()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignSystem.accent)
                            .disabled(changes.isEmpty)
                            .accessibilityIdentifier("photoSuggestionUseButton")

                            Spacer()

                            Button(L10n.text("closet.photo.ai_suggestion.edit_manual")) {
                                dismissPendingPhotoSuggestionForManualEdit()
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("photoSuggestionEditManualButton")
                        }

                    }
                }
            }
        }
    }

    private func suggestedChanges(for suggestion: ClothingPhotoTagSuggestion) -> [PhotoSuggestionChange] {
        var changes: [PhotoSuggestionChange] = []

        if draft.type != suggestion.type {
            changes.append(.type(value: suggestion.type.displayName))
        }

        let currentColor = draft.color.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedColor = suggestion.color.trimmingCharacters(in: .whitespacesAndNewlines)
        if !suggestedColor.isEmpty, currentColor != suggestedColor {
            changes.append(.color(value: localizedSuggestionColor(for: suggestedColor)))
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

    private func suggestedChangeFields(for suggestion: ClothingPhotoTagSuggestion) -> Set<PhotoSuggestionField> {
        Set(suggestedChanges(for: suggestion).map(\.field))
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

        static func type(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .type,
                label: L10n.text("closet.photo.ai_suggestion.type"),
                value: value
            )
        }

        static func color(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .color,
                label: L10n.text("closet.photo.ai_suggestion.color"),
                value: value
            )
        }

        static func seasons(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .seasons,
                label: L10n.text("closet.photo.ai_suggestion.seasons"),
                value: value
            )
        }

        static func formality(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .formality,
                label: L10n.text("closet.photo.ai_suggestion.formality"),
                value: value
            )
        }

        static func warmth(value: String) -> PhotoSuggestionChange {
            PhotoSuggestionChange(
                field: .warmth,
                label: L10n.text("closet.photo.ai_suggestion.warmth"),
                value: value
            )
        }
    }

    private var allowsCloudPhotoRecognition: Bool {
        preferences.first?.cloudPhotoRecognitionEnabled ?? false
    }

    private func suggestionStatusText(for outcome: PhotoTaggingOutcome) -> String {
        let suggestion = outcome.suggestion
        let suggestionSummary = [
            localizedSuggestionColor(for: suggestion.color),
            suggestion.type.displayName
        ]
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

    private func localizedSuggestionColor(for value: String) -> String {
        ColorResolver.localizedDisplayColor(from: value)
            ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
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

#Preview {
    AddEditItemView()
        .modelContainer(for: [ClothingItem.self, UserPreference.self], inMemory: true)
}
