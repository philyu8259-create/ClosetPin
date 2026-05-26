import XCTest
@testable import ClosetPin

final class AIStylistClientTests: XCTestCase {
    func testFallbackExplanationMentionsProvidedItemColorsAndTypes() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy"),
                clothingItem(type: .shoes, color: "black")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("white top"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("navy bottom"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("black shoes"))
    }

    func testFallbackExplanationDoesNotInventMissingItems() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy"),
                clothingItem(type: .shoes, color: "black")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("dress"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("tie"))
    }

    func testFallbackExplanationOmitsBlankWhitespaceAndNewlineColors() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "   "),
                clothingItem(type: .bottom, color: "\n"),
                clothingItem(type: .shoes, color: "navy\nblue")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.containsWholeWord("top"))
        XCTAssertTrue(explanation.containsWholeWord("bottom"))
        XCTAssertTrue(explanation.containsWholeWord("shoes"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("navy"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("\n"))
    }

    func testFallbackExplanationRejectsColorsContainingClothingNouns() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "navy dress"),
                clothingItem(type: .bottom, color: "black-tie"),
                clothingItem(type: .shoes, color: "white")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.containsWholeWord("top"))
        XCTAssertTrue(explanation.containsWholeWord("bottom"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("white shoes"))
        XCTAssertFalse(explanation.containsWholeWord("dress"))
        XCTAssertFalse(explanation.containsWholeWord("tie"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("navy dress"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("black-tie"))
    }

    func testFallbackExplanationOmitsPunctuationColors() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "navy."),
                clothingItem(type: .bottom, color: "gray/blue"),
                clothingItem(type: .shoes, color: "brown")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.containsWholeWord("top"))
        XCTAssertTrue(explanation.containsWholeWord("bottom"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("brown shoes"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("navy."))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("gray/blue"))
    }

    func testFallbackExplanationDoesNotMentionAbsentControlledOrCommonItemTypes() async throws {
        let actualTypes: Set<ClothingType> = [.top, .bottom, .shoes]
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy"),
                clothingItem(type: .shoes, color: "black")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)
        let absentControlledTypes = ClothingType.allCases
            .filter { !actualTypes.contains($0) }
            .map(\.rawValue)
        let absentCommonNouns = ["dress", "tie", "suit", "watch"]

        for noun in absentControlledTypes + absentCommonNouns {
            XCTAssertFalse(
                explanation.containsWholeWord(noun),
                "Fallback explanation should not invent absent item noun: \(noun)"
            )
        }
    }

    func testFallbackExplanationHandlesEmptyCandidate() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|empty",
            items: [],
            score: 0,
            explanationSeed: "empty"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertEqual(explanation, "No outfit items were available to explain.")
    }

    func testDailyOfficeExplanationUsesPracticalOfficeLanguage() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "blue"),
                clothingItem(type: .bottom, color: "gray"),
                clothingItem(type: .shoes, color: "black")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("practical"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("balanced"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("workday"))
    }

    func testImportantMeetingExplanationUsesPolishedFormalLanguage() async throws {
        let candidate = OutfitCandidate(
            id: "importantMeeting|seed",
            items: [
                clothingItem(type: .blazer, color: "charcoal"),
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy"),
                clothingItem(type: .shoes, color: "black")
            ],
            score: 12,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .importantMeeting)

        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("formal"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("polished"))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains("higher-stakes work moment"))
    }

    func testFallbackExplanationIsInclusiveAndGenderNeutral() async throws {
        let candidate = OutfitCandidate(
            id: "importantMeeting|seed",
            items: [
                clothingItem(type: .blazer, color: "charcoal"),
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy"),
                clothingItem(type: .shoes, color: "black")
            ],
            score: 12,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .importantMeeting)
        let genderSpecificTerms = ["women", "men", "female", "male", "her", "his"]

        for term in genderSpecificTerms {
            XCTAssertFalse(
                explanation.containsWholeWord(term),
                "Fallback explanation should not contain gender-specific term: \(term)"
            )
        }
    }
}

private extension AIStylistClientTests {
    func clothingItem(type: ClothingType, color: String) -> ClothingItem {
        ClothingItem(
            photoLocalPath: "/tmp/\(type.rawValue).jpg",
            type: type,
            color: color,
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Closet"
        )
    }
}

private extension String {
    func containsWholeWord(_ term: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
        return range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
