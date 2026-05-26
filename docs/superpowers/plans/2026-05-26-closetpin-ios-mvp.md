# ClosetPin iOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first shippable iOS local-first ClosetPin MVP for working professionals, with early validation skewing toward professional women while still supporting men: 10-minute work capsule onboarding, local closet management, office/meeting outfit recommendations, feedback, and AI-assisted explanation boundaries.

**Architecture:** Native SwiftUI app generated with XcodeGen. Keep domain models, recommendation scoring, AI abstraction, local persistence, and UI screens separated so the recommendation engine can be tested without launching the app. Store clothing images locally and structured data in SwiftData.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XcodeGen, xcodebuild, GPT Image for app visual assets when needed.

---

## File Structure

- Create: `project.yml` - XcodeGen project definition.
- Create: `.gitignore` - ignores Xcode, SwiftPM, derived data, and generated brainstorming artifacts.
- Create: `ClosetPin/App/ClosetPinApp.swift` - app entrypoint and model container.
- Create: `ClosetPin/App/AppRootView.swift` - tab shell.
- Create: `ClosetPin/Domain/Enums.swift` - clothing, scenario, status, season, feedback enums.
- Create: `ClosetPin/Domain/ClothingItem.swift` - SwiftData model for clothing.
- Create: `ClosetPin/Domain/Outfit.swift` - SwiftData model for outfit results.
- Create: `ClosetPin/Domain/OutfitFeedback.swift` - SwiftData feedback model.
- Create: `ClosetPin/Domain/UserPreference.swift` - SwiftData user preference model.
- Create: `ClosetPin/Recommendation/RecommendationInput.swift` - input context for recommendations.
- Create: `ClosetPin/Recommendation/OutfitCandidate.swift` - candidate output and score breakdown.
- Create: `ClosetPin/Recommendation/RecommendationEngine.swift` - deterministic filtering and scoring.
- Create: `ClosetPin/AI/AIStylistClient.swift` - protocol for AI explanation/tagging.
- Create: `ClosetPin/AI/LocalFallbackStylistClient.swift` - local explanation fallback.
- Create: `ClosetPin/Persistence/ImageStore.swift` - local image file storage.
- Create: `ClosetPin/Features/Onboarding/WorkCapsuleOnboardingView.swift` - first-run capsule flow.
- Create: `ClosetPin/Features/Today/TodayView.swift` - outfit-first home.
- Create: `ClosetPin/Features/Closet/ClosetView.swift` - grouped item list.
- Create: `ClosetPin/Features/Closet/AddEditItemView.swift` - photo and tag editor.
- Create: `ClosetPin/Features/Looks/LooksView.swift` - saved and worn looks.
- Create: `ClosetPin/Features/Settings/SettingsView.swift` - preferences and local data notes.
- Create: `ClosetPin/Shared/DesignSystem.swift` - colors, spacing, reusable UI style.
- Create: `ClosetPin/Shared/SeedData.swift` - deterministic sample data for previews/tests.
- Create: `ClosetPinTests/RecommendationEngineTests.swift` - recommendation filtering and scoring tests.
- Create: `ClosetPinTests/ImageStoreTests.swift` - local image write/read tests.
- Create: `ClosetPinUITests/ClosetPinUITests.swift` - smoke test for first-run flow.
- Create: `Assets/Generated/README.md` - documents GPT Image asset prompts and generated file names.

## Task 1: Scaffold Native iOS Project

**Files:**
- Create: `.gitignore`
- Create: `project.yml`
- Create: `ClosetPin/App/ClosetPinApp.swift`
- Create: `ClosetPin/App/AppRootView.swift`
- Create: `ClosetPin/Shared/DesignSystem.swift`

- [ ] **Step 1: Add repository ignores**

Write `.gitignore`:

```gitignore
.DS_Store
.superpowers/
DerivedData/
build/
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcuserstate
.swiftpm/
```

- [ ] **Step 2: Add XcodeGen configuration**

Write `project.yml`:

```yaml
name: ClosetPin
options:
  bundleIdPrefix: com.phil
  deploymentTarget:
    iOS: "18.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
targets:
  ClosetPin:
    type: application
    platform: iOS
    sources:
      - ClosetPin
    resources:
      - Assets
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.phil.closetpin
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: ClosetPin lets you choose clothing photos to build your local wardrobe.
        INFOPLIST_KEY_NSCameraUsageDescription: ClosetPin uses the camera so you can add clothes to your wardrobe.
    scheme:
      testTargets:
        - ClosetPinTests
        - ClosetPinUITests
  ClosetPinTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - ClosetPinTests
    dependencies:
      - target: ClosetPin
  ClosetPinUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - ClosetPinUITests
    dependencies:
      - target: ClosetPin
```

- [ ] **Step 3: Add app shell**

Write `ClosetPin/App/ClosetPinApp.swift`:

```swift
import SwiftData
import SwiftUI

@main
struct ClosetPinApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self
        ])
    }
}
```

Write `ClosetPin/App/AppRootView.swift`:

```swift
import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }

            ClosetView()
                .tabItem { Label("Closet", systemImage: "rectangle.grid.2x2") }

            LooksView()
                .tabItem { Label("Looks", systemImage: "heart") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    AppRootView()
}
```

Write `ClosetPin/Shared/DesignSystem.swift`:

```swift
import SwiftUI

enum DesignSystem {
    static let cornerRadius: CGFloat = 8
    static let spacing: CGFloat = 16

    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let ink = Color(.label)
    static let accent = Color(red: 0.24, green: 0.36, blue: 0.32)
}
```

- [ ] **Step 4: Add temporary tab screen stubs so the app builds**

Write one minimal file for each tab:

```swift
import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            Text("Today")
                .navigationTitle("Today")
        }
    }
}
```

Use the same pattern for `ClosetView`, `LooksView`, and `SettingsView`, changing the struct name and title.

- [ ] **Step 5: Generate and build project**

Run:

```bash
xcodegen generate
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds and `ClosetPin.xcodeproj` exists.

- [ ] **Step 6: Commit scaffold**

Run:

```bash
git init
git add .gitignore project.yml ClosetPin Assets ClosetPinTests ClosetPinUITests
git commit -m "chore: scaffold ClosetPin iOS app"
```

Expected: repository has an initial commit. If `Assets`, `ClosetPinTests`, or `ClosetPinUITests` directories do not exist before this step, create them with a `.gitkeep` file and include those `.gitkeep` files in the commit.

## Task 2: Implement Domain Models

**Files:**
- Create: `ClosetPin/Domain/Enums.swift`
- Create: `ClosetPin/Domain/ClothingItem.swift`
- Create: `ClosetPin/Domain/Outfit.swift`
- Create: `ClosetPin/Domain/OutfitFeedback.swift`
- Create: `ClosetPin/Domain/UserPreference.swift`
- Modify: `ClosetPin/App/ClosetPinApp.swift`

- [ ] **Step 1: Write enum definitions**

Write `ClosetPin/Domain/Enums.swift`:

```swift
import Foundation

enum ClothingType: String, CaseIterable, Codable, Identifiable {
    case top, bottom, blazer, shoes, bag, accessory, outerwear
    var id: String { rawValue }
}

enum ClothingStatus: String, CaseIterable, Codable, Identifiable {
    case available, needsWash, needsRepair, inactive
    var id: String { rawValue }
}

enum SeasonTag: String, CaseIterable, Codable, Identifiable {
    case spring, summer, autumn, winter
    var id: String { rawValue }
}

enum OutfitScenario: String, CaseIterable, Codable, Identifiable {
    case dailyOffice, importantMeeting
    var id: String { rawValue }
}

enum FeedbackType: String, CaseIterable, Codable, Identifiable {
    case wore, liked, disliked, skipped, saved, swapped
    var id: String { rawValue }
}
```

- [ ] **Step 2: Write SwiftData models**

Write `ClosetPin/Domain/ClothingItem.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ClothingItem {
    var id: UUID
    var photoLocalPath: String
    var typeRawValue: String
    var color: String
    var seasonRawValues: [String]
    var styleTags: [String]
    var formalityLevel: Int
    var warmthLevel: Int
    var storageLocation: String
    var statusRawValue: String
    var brand: String
    var size: String
    var material: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var lastWornAt: Date?
    var wearCount: Int

    init(
        id: UUID = UUID(),
        photoLocalPath: String,
        type: ClothingType,
        color: String,
        seasons: [SeasonTag],
        styleTags: [String] = [],
        formalityLevel: Int,
        warmthLevel: Int = 2,
        storageLocation: String,
        status: ClothingStatus = .available,
        brand: String = "",
        size: String = "",
        material: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.photoLocalPath = photoLocalPath
        self.typeRawValue = type.rawValue
        self.color = color
        self.seasonRawValues = seasons.map(\.rawValue)
        self.styleTags = styleTags
        self.formalityLevel = formalityLevel
        self.warmthLevel = warmthLevel
        self.storageLocation = storageLocation
        self.statusRawValue = status.rawValue
        self.brand = brand
        self.size = size
        self.material = material
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastWornAt = nil
        self.wearCount = 0
    }

    var type: ClothingType { ClothingType(rawValue: typeRawValue) ?? .top }
    var seasons: [SeasonTag] { seasonRawValues.compactMap(SeasonTag.init(rawValue:)) }
    var status: ClothingStatus { ClothingStatus(rawValue: statusRawValue) ?? .available }
}
```

Write `Outfit`, `OutfitFeedback`, and `UserPreference` with stored raw values for enum fields, UUID identifiers, and Date timestamps matching the spec.

- [ ] **Step 3: Build model layer**

Run:

```bash
xcodegen generate
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: app target builds with SwiftData models.

- [ ] **Step 4: Commit domain models**

Run:

```bash
git add ClosetPin/Domain ClosetPin/App/ClosetPinApp.swift project.yml
git commit -m "feat: add local wardrobe data models"
```

## Task 3: Build Recommendation Engine With Tests

**Files:**
- Create: `ClosetPin/Recommendation/RecommendationInput.swift`
- Create: `ClosetPin/Recommendation/OutfitCandidate.swift`
- Create: `ClosetPin/Recommendation/RecommendationEngine.swift`
- Create: `ClosetPinTests/RecommendationEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Write `ClosetPinTests/RecommendationEngineTests.swift`:

```swift
import XCTest
@testable import ClosetPin

final class RecommendationEngineTests: XCTestCase {
    func testExcludesUnavailableItems() {
        let items = [
            item(.top, status: .needsWash),
            item(.bottom),
            item(.shoes)
        ]

        let result = RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .dailyOffice,
                season: .spring,
                maximumResults: 3
            ),
            items: items,
            feedback: []
        )

        XCTAssertTrue(result.isEmpty)
    }

    func testImportantMeetingRequiresHigherFormality() {
        let items = [
            item(.top, formality: 1),
            item(.bottom, formality: 4),
            item(.shoes, formality: 4),
            item(.blazer, formality: 4)
        ]

        let result = RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .importantMeeting,
                season: .spring,
                maximumResults: 3
            ),
            items: items,
            feedback: []
        )

        XCTAssertTrue(result.isEmpty)
    }

    func testDailyOfficeReturnsCompleteOutfit() {
        let items = [
            item(.top, color: "white", formality: 3),
            item(.bottom, color: "navy", formality: 3),
            item(.shoes, color: "black", formality: 3)
        ]

        let result = RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .dailyOffice,
                season: .spring,
                maximumResults: 3
            ),
            items: items,
            feedback: []
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].items.count, 3)
        XCTAssertGreaterThan(result[0].score, 0)
    }

    private func item(
        _ type: ClothingType,
        color: String = "white",
        status: ClothingStatus = .available,
        formality: Int = 3
    ) -> ClothingItem {
        ClothingItem(
            photoLocalPath: "/tmp/\(UUID().uuidString).jpg",
            type: type,
            color: color,
            seasons: [.spring, .summer],
            formalityLevel: formality,
            storageLocation: "Closet"
        )
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClosetPinTests/RecommendationEngineTests
```

Expected: test build fails because recommendation types are not defined.

- [ ] **Step 3: Add recommendation types and implementation**

Write `RecommendationInput`, `OutfitCandidate`, and `RecommendationEngine` with this public interface:

```swift
struct RecommendationInput {
    let scenario: OutfitScenario
    let season: SeasonTag
    let maximumResults: Int
}

struct OutfitCandidate: Identifiable {
    let id: UUID
    let items: [ClothingItem]
    let score: Int
    let explanationSeed: String
}

struct RecommendationEngine {
    func recommend(
        input: RecommendationInput,
        items: [ClothingItem],
        feedback: [OutfitFeedback]
    ) -> [OutfitCandidate] {
        let available = items.filter { item in
            item.status == .available && item.seasons.contains(input.season)
        }

        let tops = available.filter { $0.type == .top }
        let bottoms = available.filter { $0.type == .bottom }
        let shoes = available.filter { $0.type == .shoes }
        let blazers = available.filter { $0.type == .blazer }

        var candidates: [OutfitCandidate] = []

        for top in tops {
            for bottom in bottoms {
                for shoe in shoes {
                    let baseItems = [top, bottom, shoe]
                    let requiredFormality = input.scenario == .importantMeeting ? 4 : 2
                    guard baseItems.allSatisfy({ $0.formalityLevel >= requiredFormality }) else {
                        continue
                    }

                    if input.scenario == .importantMeeting {
                        for blazer in blazers where blazer.formalityLevel >= requiredFormality {
                            candidates.append(candidate(for: baseItems + [blazer], scenario: input.scenario))
                        }
                    } else {
                        candidates.append(candidate(for: baseItems, scenario: input.scenario))
                    }
                }
            }
        }

        return candidates
            .sorted { $0.score > $1.score }
            .prefix(input.maximumResults)
            .map { $0 }
    }

    private func candidate(for items: [ClothingItem], scenario: OutfitScenario) -> OutfitCandidate {
        let formalityScore = items.reduce(0) { $0 + $1.formalityLevel }
        let colorVarietyPenalty = Set(items.map(\.color)).count > 3 ? 1 : 0
        let scenarioBonus = scenario == .importantMeeting ? 4 : 2
        return OutfitCandidate(
            id: UUID(),
            items: items,
            score: formalityScore + scenarioBonus - colorVarietyPenalty,
            explanationSeed: "Balanced \(scenario.rawValue) outfit using \(items.map(\.color).joined(separator: ", "))."
        )
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClosetPinTests/RecommendationEngineTests
```

Expected: all `RecommendationEngineTests` pass.

- [ ] **Step 5: Commit recommendation engine**

Run:

```bash
git add ClosetPin/Recommendation ClosetPinTests/RecommendationEngineTests.swift
git commit -m "feat: add rule-based outfit recommendations"
```

## Task 4: Add Local Image Storage

**Files:**
- Create: `ClosetPin/Persistence/ImageStore.swift`
- Create: `ClosetPinTests/ImageStoreTests.swift`

- [ ] **Step 1: Write failing image storage test**

Write `ClosetPinTests/ImageStoreTests.swift`:

```swift
import XCTest
@testable import ClosetPin

final class ImageStoreTests: XCTestCase {
    func testWritesImageDataToWardrobeDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ImageStore(baseDirectory: directory)
        let data = Data([0x01, 0x02, 0x03])

        let url = try store.saveJPEGData(data, id: UUID())

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClosetPinTests/ImageStoreTests
```

Expected: build fails because `ImageStore` is missing.

- [ ] **Step 3: Implement image store**

Write `ClosetPin/Persistence/ImageStore.swift`:

```swift
import Foundation

struct ImageStore {
    let baseDirectory: URL

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WardrobeImages", isDirectory: true)
        }
    }

    func saveJPEGData(_ data: Data, id: UUID) throws -> URL {
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let url = baseDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: url, options: [.atomic])
        return url
    }
}
```

- [ ] **Step 4: Run image tests**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClosetPinTests/ImageStoreTests
```

Expected: image storage test passes.

- [ ] **Step 5: Commit image storage**

Run:

```bash
git add ClosetPin/Persistence ClosetPinTests/ImageStoreTests.swift
git commit -m "feat: store wardrobe images locally"
```

## Task 5: Add AI Stylist Abstraction and Fallback

**Files:**
- Create: `ClosetPin/AI/AIStylistClient.swift`
- Create: `ClosetPin/AI/LocalFallbackStylistClient.swift`
- Create: `ClosetPinTests/AIStylistClientTests.swift`

- [ ] **Step 1: Write AI fallback test**

Write `ClosetPinTests/AIStylistClientTests.swift`:

```swift
import XCTest
@testable import ClosetPin

final class AIStylistClientTests: XCTestCase {
    func testFallbackExplanationOnlyMentionsProvidedItems() async throws {
        let items = [
            ClothingItem(photoLocalPath: "/tmp/top.jpg", type: .top, color: "white", seasons: [.spring], formalityLevel: 3, storageLocation: "Closet"),
            ClothingItem(photoLocalPath: "/tmp/pants.jpg", type: .bottom, color: "navy", seasons: [.spring], formalityLevel: 3, storageLocation: "Closet"),
            ClothingItem(photoLocalPath: "/tmp/shoes.jpg", type: .shoes, color: "black", seasons: [.spring], formalityLevel: 3, storageLocation: "Closet")
        ]

        let candidate = OutfitCandidate(id: UUID(), items: items, score: 10, explanationSeed: "seed")
        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.contains("white"))
        XCTAssertTrue(explanation.contains("navy"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("dress"))
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClosetPinTests/AIStylistClientTests
```

Expected: build fails because AI client files are missing.

- [ ] **Step 3: Implement protocol and fallback**

Write `ClosetPin/AI/AIStylistClient.swift`:

```swift
protocol AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String
}
```

Write `ClosetPin/AI/LocalFallbackStylistClient.swift`:

```swift
struct LocalFallbackStylistClient: AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
        let itemSummary = candidate.items
            .map { "\($0.color) \($0.type.rawValue)" }
            .joined(separator: ", ")
        switch scenario {
        case .dailyOffice:
            return "This office outfit uses \(itemSummary). It is practical, balanced, and easy to repeat on a workday."
        case .importantMeeting:
            return "This meeting outfit uses \(itemSummary). It leans more formal and keeps the overall impression polished."
        }
    }
}
```

- [ ] **Step 4: Run AI tests**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ClosetPinTests/AIStylistClientTests
```

Expected: AI fallback test passes.

- [ ] **Step 5: Commit AI abstraction**

Run:

```bash
git add ClosetPin/AI ClosetPinTests/AIStylistClientTests.swift
git commit -m "feat: add AI stylist fallback"
```

## Task 6: Implement Work Capsule Onboarding

**Files:**
- Create: `ClosetPin/Features/Onboarding/WorkCapsuleOnboardingView.swift`
- Modify: `ClosetPin/App/AppRootView.swift`
- Create: `ClosetPin/Shared/SeedData.swift`

- [ ] **Step 1: Add seed data for previews**

Write `ClosetPin/Shared/SeedData.swift`:

```swift
enum SeedData {
    static func workCapsuleItems() -> [ClothingItem] {
        [
            ClothingItem(photoLocalPath: "", type: .top, color: "white", seasons: [.spring, .summer], formalityLevel: 3, storageLocation: "Closet"),
            ClothingItem(photoLocalPath: "", type: .bottom, color: "navy", seasons: [.spring, .autumn], formalityLevel: 3, storageLocation: "Closet"),
            ClothingItem(photoLocalPath: "", type: .shoes, color: "black", seasons: [.spring, .autumn], formalityLevel: 4, storageLocation: "Shoe rack")
        ]
    }
}
```

- [ ] **Step 2: Build onboarding view**

Write `WorkCapsuleOnboardingView.swift` with a checklist showing 3 tops, 2 bottoms, 1 blazer, 2 shoes, and 1 bag. Include a primary button labeled `Start Adding Clothes` and a secondary button labeled `Use Sample Capsule`.

- [ ] **Step 3: Wire first-run routing**

Modify `AppRootView` to show onboarding when no `ClothingItem` exists. Use SwiftData `@Query`:

```swift
@Query private var clothingItems: [ClothingItem]

var body: some View {
    if clothingItems.isEmpty {
        WorkCapsuleOnboardingView()
    } else {
        tabShell
    }
}
```

- [ ] **Step 4: Build app**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: app builds and first launch route compiles.

- [ ] **Step 5: Commit onboarding**

Run:

```bash
git add ClosetPin/Features/Onboarding ClosetPin/App/AppRootView.swift ClosetPin/Shared/SeedData.swift
git commit -m "feat: add work capsule onboarding"
```

## Task 7: Implement Closet Item Entry

**Files:**
- Modify: `ClosetPin/Features/Closet/ClosetView.swift`
- Create: `ClosetPin/Features/Closet/AddEditItemView.swift`

- [ ] **Step 1: Build closet list**

Modify `ClosetView` to query `ClothingItem`, group by type, and show item color, type, status, and storage location.

- [ ] **Step 2: Build add/edit form**

Write `AddEditItemView` with:

- Photo picker or camera entry point.
- Type picker.
- Color text field.
- Season multi-select.
- Formality stepper from 1 to 5.
- Storage location text field.
- Status picker.
- Save button that inserts or updates a `ClothingItem`.

- [ ] **Step 3: Verify local save**

Run app in simulator:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: the code builds. During manual simulator QA, adding an item makes it appear in Closet and bypasses first-run onboarding.

- [ ] **Step 4: Commit closet entry**

Run:

```bash
git add ClosetPin/Features/Closet
git commit -m "feat: add closet item entry"
```

## Task 8: Implement Today Recommendations and Feedback

**Files:**
- Modify: `ClosetPin/Features/Today/TodayView.swift`
- Modify: `ClosetPin/Domain/Outfit.swift`
- Modify: `ClosetPin/Domain/OutfitFeedback.swift`

- [ ] **Step 1: Build Today UI states**

Implement states:

- Missing items: show the smallest missing category.
- Ready: show scenario picker, recommendation card, explanation, and action buttons.
- AI unavailable: show rule-based explanation from `LocalFallbackStylistClient`.

- [ ] **Step 2: Wire recommendation engine**

Use `RecommendationEngine().recommend(...)` with SwiftData items and current selected scenario. Store displayed `OutfitCandidate` in view state.

- [ ] **Step 3: Persist feedback**

On `Wore`, `Like`, `Dislike`, `Skip`, and `Save`, insert an `OutfitFeedback` record. On `Wore`, increment `wearCount` and set `lastWornAt` for each item in the candidate.

- [ ] **Step 4: Build and run tests**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: all unit tests pass and app builds.

- [ ] **Step 5: Commit Today flow**

Run:

```bash
git add ClosetPin/Features/Today ClosetPin/Domain
git commit -m "feat: recommend outfits on Today"
```

## Task 9: Implement Looks and Settings

**Files:**
- Modify: `ClosetPin/Features/Looks/LooksView.swift`
- Modify: `ClosetPin/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Build Looks view**

Show saved and worn outfits from `OutfitFeedback` and `Outfit` data. Include scenario, date, item count, and explanation.

- [ ] **Step 2: Build Settings view**

Expose:

- Default scenario.
- Preferred formality.
- Workplace dress code text field.
- AI privacy note explaining when metadata may be sent.
- Local data note explaining photos are stored on device.

- [ ] **Step 3: Build app**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: app builds and all tabs have useful MVP content.

- [ ] **Step 4: Commit secondary tabs**

Run:

```bash
git add ClosetPin/Features/Looks ClosetPin/Features/Settings
git commit -m "feat: add looks and settings screens"
```

## Task 10: Generate MVP Visual Assets With GPT Image

**Files:**
- Create: `Assets/Generated/README.md`
- Add: generated PNG files under `Assets/Generated/`

- [ ] **Step 1: Generate onboarding visual**

Use GPT Image with this prompt:

```text
Create a refined iOS onboarding illustration for a professional wardrobe app that supports both women and men. Show a compact work capsule wardrobe with shirt, blouse, blazer, tailored pants, smart shoes, and a structured work bag arranged neatly in a bright modern closet. Editorial but app-friendly, realistic clothing shapes, no text, no logos, clean neutral background, high resolution.
```

Save as `Assets/Generated/work-capsule-onboarding.png`.

- [ ] **Step 2: Generate empty closet visual**

Use GPT Image with this prompt:

```text
Create a refined empty-state illustration for a professional AI wardrobe app that supports both women and men. Show a minimal closet rail with a few elegant workwear hangers and one open space inviting the user to add clothes. No text, no logos, soft daylight, polished consumer app style, high resolution.
```

Save as `Assets/Generated/empty-closet.png`.

- [ ] **Step 3: Document asset provenance**

Write `Assets/Generated/README.md`:

```markdown
# Generated Assets

These images were generated with GPT Image for the ClosetPin MVP.

- `work-capsule-onboarding.png`: onboarding illustration for the 10-minute work capsule flow.
- `empty-closet.png`: empty closet state for the Closet tab.

Do not add third-party stock images to the MVP without recording source, license, and usage constraints.
```

- [ ] **Step 4: Commit assets**

Run:

```bash
git add Assets/Generated
git commit -m "art: add generated MVP visual assets"
```

## Task 11: Add UI Smoke Test and Final Verification

**Files:**
- Create: `ClosetPinUITests/ClosetPinUITests.swift`
- Modify: `docs/superpowers/specs/2026-05-26-closetpin-mvp-design.md` only if implementation reveals a necessary spec clarification.

- [ ] **Step 1: Add UI smoke test**

Write `ClosetPinUITests/ClosetPinUITests.swift`:

```swift
import XCTest

final class ClosetPinUITests: XCTestCase {
    func testLaunchShowsOnboardingOrToday() {
        let app = XCUIApplication()
        app.launch()

        let onboarding = app.staticTexts["10-Minute Work Capsule"]
        let today = app.navigationBars["Today"]

        XCTAssertTrue(onboarding.waitForExistence(timeout: 3) || today.waitForExistence(timeout: 3))
    }
}
```

- [ ] **Step 2: Run full test suite**

Run:

```bash
xcodebuild -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: unit and UI tests pass.

- [ ] **Step 3: Run simulator app**

Run with XcodeBuildMCP when executing this plan:

```text
Call session_show_defaults first. If project, scheme, and simulator are set correctly, call build_run_sim. If defaults are missing, set them to ClosetPin.xcodeproj, ClosetPin scheme, and an available iPhone simulator, then call build_run_sim.
```

Expected: the app launches in Simulator and shows onboarding on a clean install.

- [ ] **Step 4: Manual QA checklist**

Verify:

- First launch shows the work capsule onboarding.
- Adding a clothing item saves locally.
- Closet groups items by type.
- Today shows the missing category when the capsule is incomplete.
- Today generates at least one outfit when top, bottom, and shoes exist.
- Important meeting does not recommend low-formality items.
- Feedback buttons create local records.
- Looks shows saved or worn outfits.
- Settings explains local photos and AI data use.

- [ ] **Step 5: Commit final verification fixes**

Run:

```bash
git status --short
git add ClosetPin ClosetPinTests ClosetPinUITests docs Assets project.yml .gitignore
git commit -m "test: verify ClosetPin MVP flow"
```

Expected: working tree is clean after final commit.

## Self-Review

Spec coverage:

- Target user and positioning are implemented through Today-first app structure, onboarding copy, and office/meeting scenarios.
- 10-minute work capsule onboarding is covered by Task 6.
- Local clothing database and item fields are covered by Tasks 2, 4, and 7.
- AI recommendation boundaries are covered by Tasks 3 and 5.
- Feedback loop is covered by Task 8.
- Looks and Settings are covered by Task 9.
- GPT Image asset instruction is covered by Task 10.
- Validation and testing are covered by Tasks 3, 4, 5, and 11.

Plan consistency:

- `ClothingType`, `ClothingStatus`, `SeasonTag`, `OutfitScenario`, and `FeedbackType` names are consistent across tests and implementation tasks.
- Recommendation tests define the first engine contract before UI integration.
- SwiftData models exist before app entrypoint model container relies on them.
- AI fallback is local and does not invent items.
