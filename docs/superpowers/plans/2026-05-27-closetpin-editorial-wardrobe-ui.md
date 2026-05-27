# ClosetPin Editorial Wardrobe UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current framework-like card UI with the confirmed Editorial Wardrobe direction: image-led Today, archive-like Closet, and image-first AI Edit capture.

**Architecture:** Keep the existing SwiftUI/SwiftData app structure and avoid a navigation rewrite. Introduce a small editorial visual layer in shared components, add premium generated seed assets, then update Today, Closet, Looks, and Add/Edit surfaces in place while preserving existing domain models, tests, and UI automation identifiers.

**Tech Stack:** SwiftUI, SwiftData, XCTest/XCUITest, existing local image persistence, GPT Image for premium seed capsule artwork.

---

## File Structure

- Modify `Assets/Generated/`: add compressed generated editorial seed capsule images.
- Modify `ClosetPin/Shared/DesignSystem.swift`: add editorial tokens, image-led surfaces, overlay helpers, and reduced-border card style.
- Modify `ClosetPin/Shared/BundledPNGImage.swift`: resolve seed image paths to bundled generated assets before falling back to local file paths.
- Modify `ClosetPin/Shared/SeedData.swift`: point seed sample items at generated editorial images.
- Modify `ClosetPinTests/ClosetPinTests.swift`: update bundled asset checks to cover new generated capsule images.
- Modify `ClosetPin/Features/Today/TodayView.swift`: convert Today into the editorial cover layout with hero outfit imagery and above-fold CTA.
- Modify `ClosetPin/Features/Closet/ClosetView.swift`: convert Closet into a visual archive with image masthead, softer garment tiles, and slimmer filters.
- Modify `ClosetPin/Features/Closet/AddEditItemView.swift`: reorder visual hierarchy into image-first AI Edit confirmation while retaining one-view flow.
- Modify `ClosetPin/Features/Looks/LooksView.swift`: soften archive cards and reduce hard container feel.
- Modify `ClosetPin/Resources/en.lproj/Localizable.strings` and `ClosetPin/Resources/zh-Hans.lproj/Localizable.strings`: add and update editorial copy.
- Modify `README.md` only if final screenshot or product positioning language needs a short update after implementation.

---

### Task 1: Generate Editorial Seed Capsule Assets

**Files:**
- Create: `Assets/Generated/editorial-white-shirt.png`
- Create: `Assets/Generated/editorial-light-blue-blouse.png`
- Create: `Assets/Generated/editorial-charcoal-knit.png`
- Create: `Assets/Generated/editorial-navy-bottom.png`
- Create: `Assets/Generated/editorial-black-bottom.png`
- Create: `Assets/Generated/editorial-charcoal-blazer.png`
- Create: `Assets/Generated/editorial-black-shoes.png`
- Create: `Assets/Generated/editorial-brown-loafers.png`
- Create: `Assets/Generated/editorial-work-bag.png`
- Modify: `Assets/Generated/README.md`

- [ ] **Step 1: Generate source images with GPT Image**

Generate nine product-forward editorial clothing images. Use square composition, warm ivory background, soft studio light, realistic fabric texture, centered garment, no people, no logo, no text, no watermark.

Prompts:

```text
High-end editorial product photo of an ivory work shirt on a warm ivory studio background, quiet luxury styling, centered garment, realistic cotton and silk texture, soft shadows, no person, no mannequin, no logo, no text, square composition.
```

```text
High-end editorial product photo of a light blue work blouse on a warm ivory studio background, quiet luxury styling, centered garment, realistic soft fabric texture, soft shadows, no person, no mannequin, no logo, no text, square composition.
```

```text
High-end editorial product photo of a charcoal knit polo or refined work knit on a warm ivory studio background, quiet luxury styling, centered garment, realistic knit texture, soft shadows, no person, no mannequin, no logo, no text, square composition.
```

```text
High-end editorial product photo of navy tailored work trousers on a warm ivory studio background, quiet luxury styling, centered garment, realistic wool texture, soft shadows, no person, no mannequin, no logo, no text, square composition.
```

```text
High-end editorial product photo of black tailored work trousers on a warm ivory studio background, quiet luxury styling, centered garment, realistic wool texture, soft shadows, no person, no mannequin, no logo, no text, square composition.
```

```text
High-end editorial product photo of a charcoal structured blazer on a warm ivory studio background, quiet luxury styling, centered garment, realistic wool texture, soft shadows, no person, no mannequin, no logo, no text, square composition.
```

```text
High-end editorial product photo of black polished work shoes on a warm ivory studio background, quiet luxury styling, centered pair of shoes, realistic leather texture, soft shadows, no person, no logo, no text, square composition.
```

```text
High-end editorial product photo of brown leather loafers on a warm ivory studio background, quiet luxury styling, centered pair of shoes, realistic leather texture, soft shadows, no person, no logo, no text, square composition.
```

```text
High-end editorial product photo of a structured black work bag on a warm ivory studio background, quiet luxury styling, centered bag, realistic leather texture, soft shadows, no person, no logo, no text, square composition.
```

- [ ] **Step 2: Save generated images into `Assets/Generated/`**

Use clear file names exactly matching the files listed above. Keep the final app assets reasonably sized for simulator and device performance: target no more than 1200 px on the longest side and preferably under 600 KB per image.

- [ ] **Step 3: Update asset README**

Append this section to `Assets/Generated/README.md`:

```markdown
## Editorial Wardrobe Seed Assets

The `editorial-*.png` files are generated product-forward workwear images used by the sample capsule. They replace flat color swatches so Today and Closet can demonstrate the Editorial Wardrobe direction with real garment texture.

Asset constraints:
- Warm ivory studio background.
- Centered garment or accessory.
- No people, logos, text, or watermarks.
- Inclusive professional workwear styling.
```

- [ ] **Step 4: Verify asset files**

Run:

```bash
sips -g pixelWidth -g pixelHeight Assets/Generated/editorial-*.png
ls -lh Assets/Generated/editorial-*.png
```

Expected: every image exists, is readable, and has a reasonable mobile-friendly size.

- [ ] **Step 5: Commit assets**

```bash
git add Assets/Generated
git commit -m "assets: add editorial wardrobe capsule images"
```

---

### Task 2: Wire Bundled Seed Images Into Existing Photo Loading

**Files:**
- Modify: `ClosetPin/Shared/BundledPNGImage.swift`
- Modify: `ClosetPin/Shared/SeedData.swift`
- Modify: `ClosetPinTests/ClosetPinTests.swift`

- [ ] **Step 1: Write failing test for bundled editorial assets**

Add this test to `ClosetPinTests/ClosetPinTests.swift` near the existing asset tests:

```swift
func testEditorialSeedCapsuleAssetsAreBundled() throws {
    let assetNames = [
        "editorial-white-shirt",
        "editorial-light-blue-blouse",
        "editorial-charcoal-knit",
        "editorial-navy-bottom",
        "editorial-black-bottom",
        "editorial-charcoal-blazer",
        "editorial-black-shoes",
        "editorial-brown-loafers",
        "editorial-work-bag"
    ]

    for assetName in assetNames {
        XCTAssertNotNil(
            Bundle.main.url(forResource: assetName, withExtension: "png"),
            "Missing editorial asset: \(assetName)"
        )
    }
}
```

- [ ] **Step 2: Write failing test for seed photo path mapping**

Add this test to `ClosetPinTests/ClosetPinTests.swift`:

```swift
func testSampleCapsuleUsesEditorialGeneratedPhotoPaths() {
    let items = SeedData.workCapsuleItems()
    let paths = Set(items.map(\.photoLocalPath))

    XCTAssertTrue(paths.contains("generated/editorial-white-shirt.png"))
    XCTAssertTrue(paths.contains("generated/editorial-light-blue-blouse.png"))
    XCTAssertTrue(paths.contains("generated/editorial-charcoal-knit.png"))
    XCTAssertTrue(paths.contains("generated/editorial-navy-bottom.png"))
    XCTAssertTrue(paths.contains("generated/editorial-black-bottom.png"))
    XCTAssertTrue(paths.contains("generated/editorial-charcoal-blazer.png"))
    XCTAssertTrue(paths.contains("generated/editorial-black-shoes.png"))
    XCTAssertTrue(paths.contains("generated/editorial-brown-loafers.png"))
    XCTAssertTrue(paths.contains("generated/editorial-work-bag.png"))
}
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClosetPinTests/ClosetPinTests/testEditorialSeedCapsuleAssetsAreBundled -only-testing:ClosetPinTests/ClosetPinTests/testSampleCapsuleUsesEditorialGeneratedPhotoPaths
```

Expected: fails until assets exist and seed paths are updated.

- [ ] **Step 4: Update seed paths**

In `ClosetPin/Shared/SeedData.swift`, replace the sample `photoLocalPath` values:

```swift
photoLocalPath: "generated/editorial-white-shirt.png"
photoLocalPath: "generated/editorial-light-blue-blouse.png"
photoLocalPath: "generated/editorial-charcoal-knit.png"
photoLocalPath: "generated/editorial-navy-bottom.png"
photoLocalPath: "generated/editorial-black-bottom.png"
photoLocalPath: "generated/editorial-charcoal-blazer.png"
photoLocalPath: "generated/editorial-black-shoes.png"
photoLocalPath: "generated/editorial-brown-loafers.png"
photoLocalPath: "generated/editorial-work-bag.png"
```

- [ ] **Step 5: Update bundled image resolver**

In `ClosetPin/Shared/BundledPNGImage.swift`, update `WardrobePhoto.localImage(at:)`:

```swift
static func localImage(at path: String) -> UIImage? {
    let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPath.isEmpty else { return nil }

    if let generatedImage = generatedImage(at: trimmedPath) {
        return generatedImage
    }

    return UIImage(contentsOfFile: trimmedPath)
}

private static func generatedImage(at path: String) -> UIImage? {
    guard path.hasPrefix("generated/") else { return nil }
    let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "png") else { return nil }
    return UIImage(contentsOfFile: url.path)
}
```

- [ ] **Step 6: Run tests to verify pass**

Run the same targeted tests. Expected: both pass.

- [ ] **Step 7: Commit image wiring**

```bash
git add ClosetPin/Shared/BundledPNGImage.swift ClosetPin/Shared/SeedData.swift ClosetPinTests/ClosetPinTests.swift
git commit -m "feat: use editorial assets for sample capsule"
```

---

### Task 3: Reduce Framework Feel in the Shared Design System

**Files:**
- Modify: `ClosetPin/Shared/DesignSystem.swift`
- Test: `ClosetPinTests/ClosetPinTests.swift`

- [ ] **Step 1: Write failing token test**

Add this test to `ClosetPinTests/ClosetPinTests.swift`:

```swift
func testEditorialDesignTokensPreferSoftImageLedSurfaces() {
    XCTAssertGreaterThan(DesignSystem.Radius.editorialHero, DesignSystem.Radius.lg)
    XCTAssertGreaterThan(DesignSystem.Spacing.editorial, DesignSystem.Spacing.xl)
    XCTAssertEqual(DesignSystem.editorialOverlayOpacity, 0.54, accuracy: 0.001)
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClosetPinTests/ClosetPinTests/testEditorialDesignTokensPreferSoftImageLedSurfaces
```

Expected: fails because the new tokens do not exist.

- [ ] **Step 3: Add editorial tokens and surfaces**

In `ClosetPin/Shared/DesignSystem.swift`, extend `DesignSystem`:

```swift
static let editorialShadow = Color.black.opacity(0.18)
static let editorialOverlayOpacity: Double = 0.54

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let editorialHero: CGFloat = 42
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let editorial: CGFloat = 40
}
```

Add a reusable image-led surface:

```swift
struct EditorialImageSurface<Content: View>: View {
    let image: UIImage?
    let fallback: LinearGradient
    let height: CGFloat
    let content: Content

    init(
        image: UIImage?,
        height: CGFloat,
        fallback: LinearGradient = LinearGradient(
            colors: [DesignSystem.surface, DesignSystem.border],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.image = image
        self.height = height
        self.fallback = fallback
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    fallback
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(DesignSystem.editorialOverlayOpacity)],
                startPoint: .center,
                endPoint: .bottom
            )

            content
                .padding(DesignSystem.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.editorialHero, style: .continuous))
        .shadow(color: DesignSystem.editorialShadow, radius: 28, x: 0, y: 18)
    }
}
```

- [ ] **Step 4: Run token test**

Run the targeted token test. Expected: pass.

- [ ] **Step 5: Commit design system tokens**

```bash
git add ClosetPin/Shared/DesignSystem.swift ClosetPinTests/ClosetPinTests.swift
git commit -m "feat: add editorial image-led design tokens"
```

---

### Task 4: Convert Today Into Editorial Cover Layout

**Files:**
- Modify: `ClosetPin/Features/Today/TodayView.swift`
- Modify: `ClosetPin/Resources/en.lproj/Localizable.strings`
- Modify: `ClosetPin/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Preserve UI automation identifiers**

Before editing, confirm `TodayView.swift` still contains:

```swift
.accessibilityIdentifier("todayFeedback_wore_0")
.accessibilityIdentifier("todayFeedback_saved_0")
```

Do not remove these identifiers.

- [ ] **Step 2: Reorder Today screen**

Change Today’s `VStack` order to:

```swift
editorialHero
contextStrip
alternatives
```

The hero must appear before the context controls.

- [ ] **Step 3: Implement `editorialHero`**

Use the first candidate as the cover:

```swift
private var editorialHero: some View {
    Group {
        if let heroCandidate = candidates.first {
            TodayEditorialHero(
                candidate: heroCandidate,
                title: recommendationName,
                explanation: TodayRecommendationExplanation.text(for: heroCandidate, scenario: scenario),
                pendingActionIDs: pendingActionIDs,
                onAction: { action in record(action, for: heroCandidate) }
            )
        } else {
            MissingRecommendationView(message: missingRecommendationMessage)
        }
    }
}
```

- [ ] **Step 4: Create `TodayEditorialHero`**

Add a private SwiftUI subview in `TodayView.swift`:

```swift
private struct TodayEditorialHero: View {
    let candidate: OutfitCandidate
    let title: String
    let explanation: String
    let pendingActionIDs: Set<String>
    let onAction: (TodayFeedbackAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            EditorialImageSurface(
                image: candidate.items.first.flatMap(WardrobePhoto.localImage(for:)),
                height: 420
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label(L10n.text("today.edit.kicker"), systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.premiumGold)

                    Text(title)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(explanation)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    onAction(.wore)
                } label: {
                    Label(TodayFeedbackAction.wore.title, systemImage: TodayFeedbackAction.wore.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.accent)
                .disabled(pendingActionIDs.contains("\(candidate.id):\(FeedbackType.wore.rawValue)"))
                .accessibilityIdentifier("todayFeedback_wore_0")

                Button {
                    onAction(.save)
                } label: {
                    Image(systemName: TodayFeedbackAction.save.systemImage)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.accent)
                .disabled(pendingActionIDs.contains("\(candidate.id):\(FeedbackType.saved.rawValue)"))
                .accessibilityLabel(TodayFeedbackAction.save.title)
                .accessibilityIdentifier("todayFeedback_saved_0")
            }
        }
    }
}
```

- [ ] **Step 5: Move context controls below the hero**

Rename `contextControls` to `contextStrip` and make it visually secondary:

```swift
private var contextStrip: some View {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
        Text(L10n.text("today.context.title"))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DesignSystem.secondaryInk)
        // existing horizontal ContextChip rows
    }
}
```

Do not wrap it in a heavy bordered card.

- [ ] **Step 6: Add localized copy**

Add English:

```text
"today.edit.kicker" = "Today’s Edit";
```

Add Simplified Chinese:

```text
"today.edit.kicker" = "今日编辑";
```

- [ ] **Step 7: Run Today UI test**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClosetPinUITests/ClosetPinUITests/testTodayRecommendationCanRecordWoreFeedback
```

Expected: pass.

- [ ] **Step 8: Manual screenshot QA**

Run the app, insert sample capsule, screenshot Today. Confirm:

- Hero image is first major visual.
- `Wear Today` appears above the tab bar without scrolling.
- Context controls are visible but not dominant.

- [ ] **Step 9: Commit Today**

```bash
git add ClosetPin/Features/Today/TodayView.swift ClosetPin/Resources/en.lproj/Localizable.strings ClosetPin/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat: make today an editorial wardrobe cover"
```

---

### Task 5: Convert Closet Into a Visual Archive

**Files:**
- Modify: `ClosetPin/Features/Closet/ClosetView.swift`
- Modify: `ClosetPin/Resources/en.lproj/Localizable.strings`
- Modify: `ClosetPin/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Add archive masthead**

Add this computed property to `ClosetView`:

```swift
private var archiveMasthead: some View {
    EditorialImageSurface(
        image: filteredItems.first.flatMap(WardrobePhoto.localImage(for:)),
        height: 220
    ) {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(L10n.text("closet.archive.kicker"))
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignSystem.premiumGold)
                .textCase(.uppercase)

            Text(L10n.text("closet.archive.title"))
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white)

            Text(L10n.string("closet.archive.count.format", arguments: filteredItems.count))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.84))
        }
    }
}
```

- [ ] **Step 2: Put masthead before filters**

In `closetGrid`, order content as:

```swift
archiveMasthead
filterBar
garmentArchiveGrid
```

- [ ] **Step 3: Soften filter chips**

Keep `ContextChip`, but reduce vertical dominance by changing filter bar spacing to `DesignSystem.Spacing.sm` and avoid a surrounding card.

- [ ] **Step 4: Refine garment tile**

Update `GarmentGridCard` so:

- Image uses `aspectRatio(0.78, contentMode: .fit)`.
- Tile background is close to clear/paper, with no heavy stroke.
- Status chip remains text + icon.
- Metadata uses one or two lines only.

Concrete styling:

```swift
.background(DesignSystem.surface.opacity(0.82))
.clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
.shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 12)
```

Remove the tile border overlay unless visual QA shows the tile needs separation.

- [ ] **Step 5: Add localized copy**

English:

```text
"closet.archive.kicker" = "Archive";
"closet.archive.title" = "Work Closet";
"closet.archive.count.format" = "%d pieces ready to style";
```

Simplified Chinese:

```text
"closet.archive.kicker" = "衣橱档案";
"closet.archive.title" = "职业衣橱";
"closet.archive.count.format" = "%d 件单品可搭配";
```

- [ ] **Step 6: Run Closet UI smoke test**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClosetPinUITests/ClosetPinUITests/testAddClosetItemSmokeFlow
```

Expected: pass.

- [ ] **Step 7: Manual screenshot QA**

Run the app with sample capsule and screenshot Closet. Confirm:

- First screen feels like a visual archive.
- Garment images are recognizable.
- Filters do not dominate the page.
- Tile boundaries feel soft, not like dashboard cards.

- [ ] **Step 8: Commit Closet**

```bash
git add ClosetPin/Features/Closet/ClosetView.swift ClosetPin/Resources/en.lproj/Localizable.strings ClosetPin/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat: turn closet into an editorial archive"
```

---

### Task 6: Rework Add/Edit Into Image-First AI Edit

**Files:**
- Modify: `ClosetPin/Features/Closet/AddEditItemView.swift`
- Modify: `ClosetPin/Resources/en.lproj/Localizable.strings`
- Modify: `ClosetPin/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Preserve existing save flow**

Before editing, confirm these methods remain:

```swift
persistSelectedPhoto(_:)
stageCameraImage(_:)
applyPhotoIntelligenceIfAvailable(from:)
save()
```

Do not change the persistence transaction model in this task.

- [ ] **Step 2: Reorder sections**

In `Form`, replace:

```swift
photoSection
detailsSection
seasonsSection
levelsSection
notesSection
```

with:

```swift
editorialPhotoSection
aiEditSection
detailsSection
advancedSection
```

- [ ] **Step 3: Create `editorialPhotoSection`**

Use the existing camera and library controls, but make the image preview dominant:

```swift
private var editorialPhotoSection: some View {
    Section {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            if let image = displayPreviewImage {
                WardrobePhotoThumbnail(
                    image: image,
                    fallbackColor: ColorResolver.swatchColor(for: draft.color),
                    cornerRadius: DesignSystem.Radius.editorialHero
                )
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .accessibilityIdentifier("photoPreview")
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                // move existing camera button here
                // move existing PhotosPicker here
            }

            Text(L10n.text("closet.photo.editorial_help"))
                .font(.footnote)
                .foregroundStyle(DesignSystem.secondaryInk)
        }
    } header: {
        Text(L10n.text("closet.photo.editorial_title"))
    }
}
```

- [ ] **Step 4: Create `aiEditSection`**

Show AI suggestion status and the most recommendation-critical fields together:

```swift
private var aiEditSection: some View {
    Section(L10n.text("closet.ai_edit.section")) {
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

        seasonsSection
    }
}
```

If nested `Section` causes poor Form rendering, inline the season grid into `aiEditSection`.

- [ ] **Step 5: Create `advancedSection`**

Move storage, status, levels, and notes under a quieter section:

```swift
private var advancedSection: some View {
    Section(L10n.text("closet.ai_edit.confirmation_section")) {
        TextField(L10n.text("closet.storage_location.label"), text: $draft.storageLocation)
            .textInputAutocapitalization(.words)
            .accessibilityIdentifier("itemStorageField")

        Picker(L10n.text("closet.status.label"), selection: $draft.status) {
            ForEach(ClothingStatus.allCases) { status in
                Text(status.displayName).tag(status)
            }
        }

        Stepper(L10n.string("closet.formality.format", arguments: draft.formalityLevel), value: $draft.formalityLevel, in: 1...5)
        Stepper(L10n.string("closet.warmth.format", arguments: draft.warmthLevel), value: $draft.warmthLevel, in: 1...5)

        TextField(L10n.text("closet.notes.placeholder"), text: $draft.notes, axis: .vertical)
            .lineLimit(2...4)
    }
}
```

- [ ] **Step 6: Add localized copy**

English:

```text
"closet.photo.editorial_title" = "New Piece";
"closet.photo.editorial_help" = "Capture the garment clearly. ClosetPin will suggest the edit, and every field stays adjustable.";
"closet.ai_edit.section" = "AI Edit";
"closet.ai_edit.confirmation_section" = "Confirm Details";
```

Simplified Chinese:

```text
"closet.photo.editorial_title" = "新增单品";
"closet.photo.editorial_help" = "清晰拍下衣物。ClosetPin 会给出编辑建议，所有字段仍可修改。";
"closet.ai_edit.section" = "AI 编辑";
"closet.ai_edit.confirmation_section" = "确认详情";
```

- [ ] **Step 7: Run Add Item UI smoke test**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClosetPinUITests/ClosetPinUITests/testAddClosetItemSmokeFlow
```

Expected: pass.

- [ ] **Step 8: Manual screenshot QA**

Open Add Item from Closet. Confirm:

- Photo area is the dominant first section.
- AI suggestion status is visually premium but not loud.
- Color/storage fields remain accessible to UI tests.
- The screen feels less like a long settings form.

- [ ] **Step 9: Commit Add/Edit**

```bash
git add ClosetPin/Features/Closet/AddEditItemView.swift ClosetPin/Resources/en.lproj/Localizable.strings ClosetPin/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat: make item entry image-first"
```

---

### Task 7: Polish Looks Archive and Tab Styling

**Files:**
- Modify: `ClosetPin/Features/Looks/LooksView.swift`
- Modify: `ClosetPin/App/AppRootView.swift`

- [ ] **Step 1: Keep Looks archival**

Ensure `AppRootView.swift` uses:

```swift
LooksView()
    .tabItem { Label(L10n.text("tab.looks"), systemImage: "calendar") }
```

- [ ] **Step 2: Soften Looks cards**

In `LooksHistoryCard`, remove heavy bordered feel by using `LuxurySurfaceCard` or a new low-border archive surface. Use:

```swift
.shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
```

Keep `OutfitVisualBoard` visible when visual items exist.

- [ ] **Step 3: Run Looks unit tests**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClosetPinTests/ClosetPinTests/testLooksHistoryEntriesIncludeSavedOutfitAndWornFeedbackInReverseChronologicalOrder -only-testing:ClosetPinTests/ClosetPinTests/testOutfitVisualItemsPreserveOutfitOrderAndPhotoMetadata
```

Expected: pass.

- [ ] **Step 4: Commit Looks polish**

```bash
git add ClosetPin/Features/Looks/LooksView.swift ClosetPin/App/AppRootView.swift
git commit -m "feat: polish looks as an archive"
```

---

### Task 8: Final Verification and Visual QA

**Files:**
- Modify: only files needed to fix issues found during QA.

- [ ] **Step 1: Run full automated test suite**

Run:

```bash
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all tests pass.

- [ ] **Step 2: Run simulator for manual visual QA**

Run app on simulator, insert sample capsule, and capture screenshots for:

- Onboarding.
- Today after sample capsule.
- Closet after sample capsule.
- Add Item screen.
- Looks after recording `Wear Today`.

- [ ] **Step 3: Visual QA checklist**

Confirm:

- Today first screen is image-led.
- `Wear Today` is visible above the tab bar.
- Closet sample items show generated garment images, not color blocks.
- Filters are secondary.
- Add Item opens with photo-first AI Edit hierarchy.
- Chinese and English key buttons do not truncate.
- Status labels show icon and text.

- [ ] **Step 4: Fix any visual regressions**

If a screen still feels like a bordered dashboard:

- Remove one enclosing `LuxurySurfaceCard`.
- Reduce stroke opacity.
- Increase image height.
- Move controls below image/content.
- Replace `.secondary` text color with `DesignSystem.secondaryInk`.

- [ ] **Step 5: Final full test**

Run the full test suite again after fixes. Expected: all tests pass.

- [ ] **Step 6: Commit final fixes**

If fixes were needed:

```bash
git add ClosetPin Assets/Generated ClosetPinTests README.md
git commit -m "fix: refine editorial wardrobe visual qa"
```

- [ ] **Step 7: Push branch**

```bash
git push origin main
```

Expected: push succeeds.

---

## Self-Review

- Spec coverage: This plan covers generated assets, seed image wiring, Today editorial cover, Closet visual archive, Add/Edit image-first AI Edit, Looks archive polish, localization, tests, and manual screenshot QA.
- Completion scan: No unresolved implementation gaps are left in the plan.
- Type consistency: The plan uses existing types `ClothingItem`, `OutfitCandidate`, `ClothingStatus`, `FeedbackType`, `WardrobePhoto`, `DesignSystem`, and existing test target names.
- Scope check: This is a single UI/UX implementation pass and does not include backend, chat AI, weather, calendar, or monetization.
