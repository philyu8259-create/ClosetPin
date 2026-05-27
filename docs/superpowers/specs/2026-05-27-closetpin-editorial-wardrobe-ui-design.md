# ClosetPin Editorial Wardrobe UI Design

## Context

The current MVP works functionally, but the interface still reads as a standard SwiftUI card-and-form app. The confirmed direction is **A. Editorial Wardrobe**: ClosetPin should feel closer to a high-end fashion magazine and workwear lookbook than a wardrobe inventory tool.

The goal is not to add more UI chrome. The goal is to remove visible framework structure, make garment imagery carry the interface, and make the user feel they are opening a private editorial wardrobe advisor.

## Design Principle

ClosetPin should feel like:

> A quiet luxury workwear lookbook that happens to be intelligent.

This means:

- Large garment imagery before controls.
- Fewer bordered cards and fewer visible containers.
- Editorial typography hierarchy instead of dashboard hierarchy.
- Warm photographic surfaces, ivory paper, soft ink, and champagne accents.
- AI shown as curation and explanation, not neon technology.
- Decisions first, settings and filters second.

## Visual Direction

### Palette

Use the existing warm direction, but reduce heavy outlines and standard card fills.

- Background: warm ivory, slightly textured or image-led where possible.
- Primary text: soft ink.
- Secondary text: warm gray.
- Primary action: deep teal.
- Premium/editorial accent: champagne gold.
- Formal emphasis: deep wine.

### Surfaces

Replace “stack of rounded cards” with three surface types:

- **Editorial image surface:** full-width or large-format garment/lifestyle image areas, with text over or immediately below.
- **Floating glass dock:** tab bar and secondary controls can feel light and translucent.
- **Soft paper sheet:** used only where structured fields are necessary, with minimal border and subtle shadow.

Cards should be used sparingly. If a view has more than two bordered cards above the fold, it likely feels too framework-like.

### Imagery

The sample capsule must stop using pure color blocks as the primary visual source. Generate or include a small set of high-quality editorial workwear images:

- Ivory blouse or shirt.
- Light blue blouse.
- Charcoal knit or polo.
- Navy or black tailored bottom.
- Charcoal blazer.
- Black shoes.
- Brown loafers.
- Structured work bag.

Images should be clean, inspectable, and product-forward, not dark abstract backgrounds. The clothing should be recognizable, centered, and suitable for both women and men where possible. The overall positioning can lean professional women, but should remain inclusive and not exclude men.

## Screen Design

### Today

Today becomes the editorial cover.

Above the fold:

- Navigation title is quiet or inline.
- Main content starts with a small editorial kicker such as “Today’s Edit”.
- The recommendation name becomes the hero title, e.g. “Soft Power Office”.
- A large editorial outfit image or outfit composition dominates the first screen.
- The recommendation explanation is short and placed as editorial copy.
- The primary CTA “Wear Today / 今天穿这套” is visible without scrolling.

Context controls:

- Scenario and season controls should not dominate the top of the screen.
- They can become small inline chips, a compact top row, or a floating context sheet.
- The default state should still show a recommendation immediately.

Feedback:

- Keep one primary action: Wear Today.
- Keep Save as a secondary action.
- Move Like, Dislike, and Try Another into a quieter overflow area.

### Closet

Closet becomes a visual archive.

Above the fold:

- Use a photographic or editorial masthead instead of just title plus filters.
- Keep two-column garment browsing, but reduce hard card boundaries.
- Each garment tile should feel like a product archive image with understated metadata.

Filters:

- Chips remain useful, but should feel secondary.
- They should be slimmer and less pill-heavy than the current version.
- Filtering should not make the page feel like a dashboard.

Garment tiles:

- Image area should dominate.
- Metadata should be concise: color/name, type, status.
- Status must include icon and text, not color alone.

### Add/Edit Item

Add/Edit becomes an “AI Edit” confirmation flow.

The desired sequence:

1. Photo capture or library import.
2. Large editorial preview of the cropped garment photo.
3. AI suggested fields shown as editable editorial tags.
4. Required metadata confirmation.
5. Advanced details folded lower in the screen.

This should feel like confirming an assistant’s edit, not filling a form.

For this implementation pass, the Add/Edit screen can remain one SwiftUI view, but the visual order should change so image and AI suggestions appear before dense fields.

### Looks

Looks should feel like a saved editorial archive rather than a feedback log.

- Use timeline/archive language.
- Let outfit imagery lead.
- Reduce repeated bordered containers.
- Keep saved and worn states clear, but understated.

## Implementation Scope

This pass should deliver a visible leap in perceived quality without requiring a new backend.

In scope:

- Generate or add premium sample capsule images.
- Update seed/sample image resolution behavior so sample items display real images.
- Rework Today into the editorial cover layout.
- Rework Closet into a softer visual archive.
- Polish Add/Edit above-the-fold into image-first AI Edit.
- Reduce borders, hard cards, and default SwiftUI form feeling where practical.
- Keep bilingual strings matched.
- Preserve existing flows and UI tests where possible.

Out of scope for this pass:

- Real chat-based AI concierge.
- Weather/calendar integration.
- Full multi-step navigation rewrite for Add/Edit.
- Backend image recognition changes.
- New monetization or subscription UI.

## Acceptance Criteria

- Today first screen feels image-led and editorial, not dashboard-like.
- “Wear Today / 今天穿这套” is visible without scrolling on a modern iPhone simulator.
- Closet first screen uses real garment imagery and feels like a workwear archive, not an inventory list.
- Add/Edit first screen prioritizes photo and AI suggestion confirmation over dense fields.
- Sample capsule no longer appears as flat color blocks.
- Bilingual layouts do not overlap or truncate key actions.
- Status labels include both icon and text.
- Existing core tests and UI smoke flows pass.
- The app remains usable with user-imported local photos.

## Testing Plan

- Unit tests:
  - Existing localization key parity test must pass.
  - Existing status metadata test must pass.
  - Existing seed asset bundle test should be updated if new asset names are introduced.

- UI tests:
  - Launch smoke.
  - Use sample capsule routes to Today.
  - Wear Today action records feedback.
  - Add closet item smoke flow.

- Manual simulator QA:
  - Capture screenshots of Today and Closet after inserting sample capsule.
  - Verify Today CTA is visible above the tab bar.
  - Verify Closet tiles show recognizable garment images.
  - Verify Add/Edit photo area and AI suggestion status are visible before dense metadata.

## Risks

- Generated garment images may look too fashion-advertising-like and make the app less practical. Keep images product-forward and inspectable.
- Too much editorial layout can hide controls. Keep the main action and filtering reachable.
- SwiftUI forms may continue to look standard unless Add/Edit is visually reorganized. Prioritize image-first ordering even before a complete multi-step flow.
- Large image assets can increase app size. Use compressed PNG/JPEG assets sized for mobile display.
