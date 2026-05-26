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
