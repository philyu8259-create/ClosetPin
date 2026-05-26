# ClosetPin MVP Design

Date: 2026-05-26

## Summary

ClosetPin is an iOS local-first AI outfit assistant for professional women. The MVP focuses on two high-frequency workplace needs:

- Daily office outfits that save time and avoid repetitive dressing.
- Important work occasions such as meetings, client visits, and business meals where the user wants a safer, more polished recommendation.

The product should open on the question users care about most: "What should I wear today or tomorrow?" It should not feel like a closet inventory tool, even though a structured closet database powers the recommendations.

## Product Positioning

Primary positioning:

> A local-first AI outfit assistant that helps professional women choose office and meeting outfits from clothes they already own.

MVP promise:

> Add a small work capsule wardrobe in about 10 minutes, then get 1-3 practical outfit recommendations for daily office or important meeting scenarios.

## Target User

The first target user is a professional woman who wants to dress appropriately and confidently for work without spending too much time deciding outfits. She may have enough clothes, but struggles with:

- Repeating the same safe combinations.
- Not knowing whether an outfit is formal enough for a meeting.
- Forgetting what she owns or where items are stored.
- Wanting a recommendation that explains why the outfit works.

## MVP Product Principles

1. The app opens to outfit value, not closet management.
2. The first session must produce a useful recommendation quickly.
3. AI recommendations must only use real user-owned items.
4. Structured clothing data and rule scoring come before LLM explanation.
5. Manual confirmation is acceptable in MVP because accuracy matters more than fully automated recognition.
6. Cloud sync, accounts, and monetization should not block the first validation.

## Core Experience

### First Launch

The user sees a short onboarding flow framed around a "10-minute work capsule."

The app asks the user to add enough items to produce credible office outfits:

- 3 tops, such as blouse, shirt, knit, or tee.
- 2 bottoms, such as pants or skirt.
- 1 blazer or work outer layer.
- 2 shoes.
- 1 bag.

The app should allow users to skip exact counts, but it should explain that better recommendations need enough items across categories.

### Add Clothing Item

For each item, the user can:

- Take or select a photo.
- Confirm item type.
- Confirm primary color.
- Select season suitability.
- Select formality level.
- Enter storage location.
- Mark status: available, needs wash, needs repair, or inactive.

Optional fields can be present but should not block saving:

- Brand.
- Size.
- Material.
- Style tags.
- Notes.

### Today Screen

The app opens to the Today tab. It shows:

- Today or tomorrow context.
- Selected scenario: daily office or important meeting.
- Optional weather note.
- Recommended outfit card.
- Reasoning summary.
- Actions: wore, like, dislike, swap item, save look.

If the closet does not have enough items, the Today screen should show the smallest missing category, not a generic empty state.

### Outfit Recommendation

The user selects or confirms:

- Scenario: daily office or important meeting.
- Date: today or tomorrow.
- Optional formality setting.
- Optional weather or temperature note.

The app returns 1-3 outfit suggestions. Each suggestion contains:

- Top.
- Bottom.
- Shoes.
- Optional blazer or outer layer.
- Optional bag or accessory.
- Explanation of why the outfit works.
- Any caveats, such as "better for mild weather" or "choose this for a more formal meeting."

### Feedback Loop

The app records user feedback:

- Wore.
- Liked.
- Disliked.
- Skipped.
- Saved look.
- Swapped item.

Feedback should influence future scoring. For MVP, this can be simple local weighting instead of a complex personalization model.

## Information Architecture

The MVP has four main tabs.

### Today

Primary screen. Shows outfit recommendations for today or tomorrow.

### Closet

Shows clothing items grouped by category. Supports adding, editing, filtering, and viewing item details.

### Looks

Shows saved outfits and worn history. Supports viewing feedback and reusing an outfit.

### Settings

Contains profile preferences, default work style, color preferences, AI settings, and local data management.

## Data Model

### ClothingItem

Fields:

- id
- photoLocalPath
- type
- color
- seasonTags
- styleTags
- formalityLevel
- warmthLevel
- storageLocation
- status
- brand
- size
- material
- notes
- createdAt
- updatedAt
- lastWornAt
- wearCount

Required for MVP:

- photoLocalPath
- type
- color
- seasonTags
- formalityLevel
- storageLocation
- status

### Outfit

Fields:

- id
- itemIds
- scenario
- dateContext
- weatherNote
- score
- explanation
- createdAt
- savedAt
- wornAt

### OutfitFeedback

Fields:

- id
- outfitId
- feedbackType
- itemIds
- scenario
- createdAt

Feedback types:

- wore
- liked
- disliked
- skipped
- saved
- swapped

### UserPreference

Fields:

- defaultScenario
- preferredFormality
- preferredColors
- avoidedColors
- preferredStyles
- avoidedStyles
- workplaceDressCode

## Recommendation Logic

The recommendation system has three layers.

### Layer 1: Structured Closet Filtering

Filter out invalid or unsuitable items:

- Items marked needs wash, needs repair, or inactive.
- Items outside the selected season or weather context.
- Items that are too casual for important meeting scenarios.
- Items that cannot form a complete outfit category set.

### Layer 2: Rule Scoring

Score candidate combinations using local logic:

- Scenario fit.
- Color harmony.
- Formality match.
- Season and warmth match.
- Recent wear avoidance.
- User likes and dislikes.
- Complete category coverage.

Important meeting recommendations should bias toward safer and more formal combinations. Daily office recommendations can allow more variety.

### Layer 3: AI Explanation and Refinement

The LLM receives only structured candidate combinations and user context. It should:

- Explain why the chosen outfit works.
- Point out scenario fit.
- Suggest small swaps from available items.
- Avoid inventing any item not present in the user's closet.

The LLM should not be the source of truth for item availability or outfit validity.

## AI Image Recognition

MVP should treat image recognition as assistive, not authoritative.

Expected MVP behavior:

- The app may suggest type and color from the image.
- The user must confirm or edit the suggested tags.
- Brand, material, and nuanced style recognition are optional and should not block the flow.

Automatic recognition can become more advanced in a later phase.

## Technical Direction

MVP platform:

- iOS first.
- SwiftUI for UI.
- SwiftData or a local SQLite-backed persistence layer for structured data.
- Local file storage for clothing photos.
- AI API for optional tag suggestions and outfit explanations.

The MVP should not require:

- Account creation.
- Cloud sync.
- Remote image storage.
- Subscription/paywall infrastructure.
- Android support.

## Privacy Direction

Because wardrobe photos are personal, the MVP should be local-first by default.

Required privacy behavior:

- Store photos locally on device.
- Clearly indicate when data is sent to an AI service.
- Avoid uploading the whole closet unless required for a specific AI request.
- Prefer sending structured item metadata for recommendation explanations.

## Error Handling

### Not Enough Items

If the user cannot generate an outfit, the app should say which category is missing, such as "Add one pair of work shoes to generate office outfits."

### AI Unavailable

If AI is unavailable, the app should still provide a rule-based outfit suggestion with a shorter local explanation.

### Poor Image Recognition

If recognition confidence is low, the app should skip auto-filled values and ask the user to select tags manually.

### Missing Weather

Weather should be optional in MVP. If unavailable, the app uses season tags and user-selected context.

## Testing Strategy

MVP testing should cover:

- Adding and editing clothing items.
- Completing 10-minute work capsule onboarding.
- Generating office and meeting recommendations from seeded closet data.
- Excluding unavailable, dirty, repaired, inactive, or unsuitable items.
- Saving looks and recording feedback.
- Recommendation behavior when categories are missing.
- AI fallback when network or API calls fail.

Manual QA should verify:

- First-run flow can produce a recommendation quickly.
- Today tab does not feel like an empty database screen.
- Important meeting recommendations are more conservative than daily office recommendations.
- The user can understand why each outfit was recommended.

## Out Of Scope For MVP

The following are intentionally deferred:

- Full account system.
- Cloud sync.
- Android app.
- Subscription and paywall.
- Travel packing mode.
- E-commerce purchase recommendations.
- Advanced automatic brand/material recognition.
- Social sharing.
- Community outfit feed.
- Full closet analytics dashboard.

## Success Criteria

The MVP should be considered validated if test users can:

- Add at least 12-20 workplace-relevant clothing items without frustration.
- Generate a useful outfit recommendation in the first session.
- Understand why an outfit was recommended.
- Save or wear at least one recommended outfit.
- Return to the app for another workday or meeting recommendation.

