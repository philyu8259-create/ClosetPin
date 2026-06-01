import XCTest
@testable import ClosetPin

@MainActor
final class AIStylistClientTests: XCTestCase {
    func testLocalPhotoIntelligenceSuggestsDominantColorAndPracticalDefaults() throws {
        let image = makeSolidImage(color: .systemBlue)

        let suggestion = try XCTUnwrap(LocalPhotoIntelligenceClient().suggestTags(for: image))

        XCTAssertEqual(suggestion.color, "blue")
        XCTAssertEqual(suggestion.type, .top)
        XCTAssertEqual(suggestion.seasons, [.spring, .summer, .autumn])
        XCTAssertEqual(suggestion.formalityLevel, 3)
        XCTAssertEqual(suggestion.warmthLevel, 2)
        XCTAssertGreaterThan(suggestion.confidence, 0)
    }

    func testPhotoTagSuggestionFillsEmptyDraftFields() {
        var draft = AddEditItemDraft()
        let suggestion = ClothingPhotoTagSuggestion(
            type: .shoes,
            color: "black",
            seasons: [.autumn, .winter],
            formalityLevel: 4,
            warmthLevel: 3,
            confidence: 0.72,
            source: .localHeuristic
        )

        suggestion.apply(to: &draft)

        XCTAssertEqual(draft.type, .shoes)
        XCTAssertEqual(draft.color, "black")
        XCTAssertEqual(draft.selectedSeasons, [.autumn, .winter])
        XCTAssertEqual(draft.formalityLevel, 4)
        XCTAssertEqual(draft.warmthLevel, 3)
    }

    func testPhotoTagSuggestionDoesNotOverwriteManualDraftFields() {
        var draft = AddEditItemDraft()
        draft.type = .bag
        draft.color = "Ivory"
        draft.selectedSeasons = [.spring]
        draft.seasonSelectionSource = .manual
        draft.formalityLevel = 5
        draft.warmthLevel = 1
        let suggestion = ClothingPhotoTagSuggestion(
            type: .shoes,
            color: "black",
            seasons: [.autumn, .winter],
            formalityLevel: 4,
            warmthLevel: 3,
            confidence: 0.72,
            source: .localHeuristic
        )

        suggestion.apply(to: &draft)

        XCTAssertEqual(draft.type, .bag)
        XCTAssertEqual(draft.color, "Ivory")
        XCTAssertEqual(draft.selectedSeasons, [.spring])
        XCTAssertEqual(draft.formalityLevel, 5)
        XCTAssertEqual(draft.warmthLevel, 1)
    }

    func testCloudPhotoTaggingRequestContainsOnlyPhotoPayloadAndLocale() throws {
        let image = makeSolidImage(color: .systemBlue)

        let body = try CloudPhotoTaggingClient.makeRequestBody(for: image, localeIdentifier: "en_US")
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNotNil(payload["imageJPEGBase64"] as? String)
        XCTAssertEqual(payload["localeIdentifier"] as? String, "en_US")
        XCTAssertNil(payload["closetItems"])
        XCTAssertNil(payload["wardrobe"])
        XCTAssertNil(payload["userPreference"])
    }

    func testCloudPhotoTaggingClientDecodesRemoteSuggestion() throws {
        let json = """
        {
          "type": "shoes",
          "color": "black",
          "seasons": ["autumn", "winter", "unsupported"],
          "formalityLevel": 8,
          "warmthLevel": 0,
          "confidence": 0.82
        }
        """

        let suggestion = try XCTUnwrap(CloudPhotoTaggingClient.decodeSuggestion(from: Data(json.utf8)))

        XCTAssertEqual(suggestion.type, .shoes)
        XCTAssertEqual(suggestion.color, "black")
        XCTAssertEqual(suggestion.seasons, [.autumn, .winter])
        XCTAssertEqual(suggestion.formalityLevel, 5)
        XCTAssertEqual(suggestion.warmthLevel, 1)
        XCTAssertEqual(suggestion.confidence, 0.82, accuracy: 0.001)
        XCTAssertEqual(suggestion.source, .remoteAI)
    }

    func testCloudStylistExplanationRequestContainsOnlyCurrentOutfitMetadata() throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy")
            ],
            score: 142,
            explanationSeed: "seed"
        )

        let body = try CloudStylistExplanationClient.makeRequestBody(
            for: candidate,
            scenario: .dailyOffice,
            localeIdentifier: "en_US"
        )
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let items = try XCTUnwrap(payload["items"] as? [[String: Any]])

        XCTAssertEqual(payload["candidateId"] as? String, "dailyOffice|seed")
        XCTAssertEqual(payload["scenario"] as? String, "dailyOffice")
        XCTAssertEqual(payload["score"] as? Int, 142)
        XCTAssertEqual(payload["localeIdentifier"] as? String, "en_US")
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?["type"] as? String, "top")
        XCTAssertEqual(items.first?["color"] as? String, "white")
        XCTAssertNil(items.first?["photoLocalPath"])
        XCTAssertNil(payload["closetItems"])
        XCTAssertNil(payload["wardrobe"])
        XCTAssertNil(payload["userPreference"])
    }

    func testCloudStylistExplanationDecodesTrimmedExplanationAndRejectsEmptyText() throws {
        let validJSON = #"{"explanation":"  Works because the light top balances the navy base.  "}"#
        let emptyJSON = #"{"explanation":"   "}"#

        let explanation = try CloudStylistExplanationClient.decodeExplanation(from: Data(validJSON.utf8))
        let emptyExplanation = try CloudStylistExplanationClient.decodeExplanation(from: Data(emptyJSON.utf8))

        XCTAssertEqual(explanation, "Works because the light top balances the navy base.")
        XCTAssertNil(emptyExplanation)
    }

    func testStylistExplanationPipelineUsesRemoteWhenAvailableAndFallsBackLocally() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "white"),
                clothingItem(type: .bottom, color: "navy")
            ],
            score: 142,
            explanationSeed: "seed"
        )
        let localExplanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)
        let remotePipeline = StylistExplanationPipeline(
            localClient: LocalFallbackStylistClient(),
            remoteClient: StubAIStylistClient(explanation: "AI explains the balance in one simple sentence.")
        )
        let fallbackPipeline = StylistExplanationPipeline(
            localClient: LocalFallbackStylistClient(),
            remoteClient: FailingAIStylistClient()
        )

        let remoteExplanation = await remotePipeline.explanation(for: candidate, scenario: .dailyOffice)
        let fallbackExplanation = await fallbackPipeline.explanation(for: candidate, scenario: .dailyOffice)

        XCTAssertEqual(remoteExplanation, "AI explains the balance in one simple sentence.")
        XCTAssertEqual(fallbackExplanation, localExplanation)
    }

    func testPhotoTaggingPipelineUsesCloudSuggestionWhenAllowed() async {
        let remoteSuggestion = ClothingPhotoTagSuggestion(
            type: .bag,
            color: "black",
            seasons: [.autumn, .winter],
            formalityLevel: 4,
            warmthLevel: 2,
            confidence: 0.9,
            source: .remoteAI
        )
        let pipeline = PhotoTaggingPipeline(
            localClient: LocalPhotoIntelligenceClient(),
            cloudClient: StubAsyncPhotoTaggingClient(suggestion: remoteSuggestion)
        )

        let outcome = await pipeline.suggestionOutcome(for: makeSolidImage(color: .systemBlue), allowsCloudRecognition: true)

        XCTAssertEqual(outcome?.suggestion, remoteSuggestion)
        XCTAssertEqual(outcome?.delivery, .remoteAI)
    }

    func testPhotoTaggingPipelineFallsBackToLocalWhenCloudIsDisabledOrFails() async throws {
        let pipeline = PhotoTaggingPipeline(
            localClient: LocalPhotoIntelligenceClient(),
            cloudClient: FailingAsyncPhotoTaggingClient()
        )

        let disabledOutcomeResult = await pipeline.suggestionOutcome(
            for: makeSolidImage(color: .systemBlue),
            allowsCloudRecognition: false
        )
        let failedOutcomeResult = await pipeline.suggestionOutcome(
            for: makeSolidImage(color: .systemBlue),
            allowsCloudRecognition: true
        )
        let disabledOutcome = try XCTUnwrap(disabledOutcomeResult)
        let failedOutcome = try XCTUnwrap(failedOutcomeResult)

        XCTAssertEqual(disabledOutcome.suggestion.source, .localHeuristic)
        XCTAssertEqual(disabledOutcome.delivery, .localOnly)
        XCTAssertEqual(failedOutcome.suggestion.source, .localHeuristic)
        XCTAssertEqual(failedOutcome.delivery, .localAfterCloudUnavailable)
    }

    func testPhotoTaggingPipelineReportsLocalFallbackWhenCloudIsEnabledButNotConfigured() async throws {
        let pipeline = PhotoTaggingPipeline(
            localClient: LocalPhotoIntelligenceClient(),
            cloudClient: nil
        )

        let outcomeResult = await pipeline.suggestionOutcome(
            for: makeSolidImage(color: .systemBlue),
            allowsCloudRecognition: true
        )
        let outcome = try XCTUnwrap(outcomeResult)

        XCTAssertEqual(outcome.suggestion.source, .localHeuristic)
        XCTAssertEqual(outcome.delivery, .localAfterCloudUnavailable)
    }

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

        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .top, color: "white")))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .bottom, color: "navy")))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .shoes, color: "black")))
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

        XCTAssertTrue(explanation.containsType(.top))
        XCTAssertTrue(explanation.containsType(.bottom))
        XCTAssertTrue(explanation.containsType(.shoes))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("navy"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("\n"))
    }

    func testFallbackExplanationRejectsColorsContainingClothingNouns() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "blue shirt"),
                clothingItem(type: .bottom, color: "red skirt"),
                clothingItem(type: .shoes, color: "tan jacket"),
                clothingItem(type: .bag, color: "green scarf"),
                clothingItem(type: .shoes, color: "white")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.containsType(.top))
        XCTAssertTrue(explanation.containsType(.bottom))
        XCTAssertTrue(explanation.containsType(.bag))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .shoes, color: "white")))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("blue shirt"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("red skirt"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("tan jacket"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("green scarf"))
    }

    func testFallbackExplanationRejectsAdditionalClothingNounsInColorMetadata() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "black pants"),
                clothingItem(type: .bottom, color: "navy dress"),
                clothingItem(type: .shoes, color: "black-tie"),
                clothingItem(type: .outerwear, color: "camel coat")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("black pants"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("navy dress"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("black-tie"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("camel coat"))
        XCTAssertFalse(explanation.containsWholeWord("pants"))
        XCTAssertFalse(explanation.containsWholeWord("dress"))
        XCTAssertFalse(explanation.containsWholeWord("tie"))
        XCTAssertFalse(explanation.containsWholeWord("coat"))
    }

    func testFallbackExplanationOmitsNonColorPhrases() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "very formal"),
                clothingItem(type: .bottom, color: "office ready"),
                clothingItem(type: .shoes, color: "nice work")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.containsType(.top))
        XCTAssertTrue(explanation.containsType(.bottom))
        XCTAssertTrue(explanation.containsType(.shoes))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("very formal"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("office ready"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("nice work"))
    }

    func testFallbackExplanationAllowsKnownColorTokensModifiersAndSupportedHyphenColors() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "navy"),
                clothingItem(type: .bottom, color: "light blue"),
                clothingItem(type: .shoes, color: "blue-green")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .top, color: "navy")))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .bottom, color: "light blue")))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .shoes, color: "blue-green")))
    }

    func testFallbackExplanationAllowsChineseColorsAndRejectsChineseClothingNouns() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|zh-seed",
            items: [
                clothingItem(type: .top, color: "白色"),
                clothingItem(type: .bottom, color: "海军蓝"),
                clothingItem(type: .shoes, color: "黑色鞋"),
                clothingItem(type: .bag, color: "棕色包")
            ],
            score: 10,
            explanationSeed: "zh-seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .top, color: "白色")))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .bottom, color: "海军蓝")))
        XCTAssertTrue(explanation.containsType(.shoes))
        XCTAssertTrue(explanation.containsType(.bag))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("黑色鞋"))
        XCTAssertFalse(explanation.localizedCaseInsensitiveContains("棕色包"))
    }

    func testFallbackExplanationOmitsUnsupportedPunctuationButAllowsSupportedHyphens() async throws {
        let candidate = OutfitCandidate(
            id: "dailyOffice|seed",
            items: [
                clothingItem(type: .top, color: "navy."),
                clothingItem(type: .bottom, color: "gray/blue"),
                clothingItem(type: .shoes, color: "blue-green")
            ],
            score: 10,
            explanationSeed: "seed"
        )

        let explanation = try await LocalFallbackStylistClient().explain(candidate: candidate, scenario: .dailyOffice)

        XCTAssertTrue(explanation.containsType(.top))
        XCTAssertTrue(explanation.containsType(.bottom))
        XCTAssertTrue(explanation.localizedCaseInsensitiveContains(itemDescription(type: .shoes, color: "blue-green")))
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
            .flatMap { type in
                type.summaryName.count > 1 ? [type.rawValue, type.summaryName] : [type.rawValue]
            }
        let absentCommonNouns = ["dress", "tie", "suit", "watch"]

        for noun in absentControlledTypes + absentCommonNouns {
            XCTAssertFalse(
                explanation.containsLocalizedTerm(noun),
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

        XCTAssertEqual(explanation, L10n.text("recommendation.explanation.empty"))
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

        let itemSummary = [
            itemDescription(type: .top, color: "blue"),
            itemDescription(type: .bottom, color: "gray"),
            itemDescription(type: .shoes, color: "black")
        ].joined(separator: ", ")
        XCTAssertEqual(
            explanation,
            L10n.string("recommendation.explanation.daily_office.format", arguments: itemSummary)
        )
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

        let itemSummary = [
            itemDescription(type: .blazer, color: "charcoal"),
            itemDescription(type: .top, color: "white"),
            itemDescription(type: .bottom, color: "navy"),
            itemDescription(type: .shoes, color: "black")
        ].joined(separator: ", ")
        XCTAssertEqual(
            explanation,
            L10n.string("recommendation.explanation.important_meeting.format", arguments: itemSummary)
        )
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

    func itemDescription(type: ClothingType, color: String) -> String {
        "\(color) \(type.summaryName)"
    }

    func makeSolidImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 60, height: 80)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 80))
        }
    }
}

private struct StubAsyncPhotoTaggingClient: AsyncClothingPhotoTaggingClient {
    let suggestion: ClothingPhotoTagSuggestion?

    func suggestTags(for image: UIImage) async throws -> ClothingPhotoTagSuggestion? {
        suggestion
    }
}

private struct FailingAsyncPhotoTaggingClient: AsyncClothingPhotoTaggingClient {
    func suggestTags(for image: UIImage) async throws -> ClothingPhotoTagSuggestion? {
        throw URLError(.badServerResponse)
    }
}

private struct StubAIStylistClient: AIStylistClient {
    let explanation: String

    @MainActor
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
        explanation
    }
}

private struct FailingAIStylistClient: AIStylistClient {
    @MainActor
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
        throw URLError(.badServerResponse)
    }
}

private extension String {
    func containsType(_ type: ClothingType) -> Bool {
        localizedCaseInsensitiveContains(type.summaryName)
    }

    func containsLocalizedTerm(_ term: String) -> Bool {
        if term.rangeOfCharacter(from: .letters) != nil && term.unicodeScalars.allSatisfy(\.isASCII) {
            return containsWholeWord(term)
        }
        return localizedCaseInsensitiveContains(term)
    }

    func containsWholeWord(_ term: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
        return range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
