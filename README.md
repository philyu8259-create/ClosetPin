# ClosetPin

ClosetPin is an iOS MVP for a bilingual AI wardrobe assistant focused on professional women while also supporting men's workwear. Users can build a local wardrobe from camera or photo library images, create office scenarios, and save outfit history.

## Current MVP

- Add clothing with camera capture or photo library selection
- Store item metadata such as color, season, formality, warmth, status, notes, and storage location
- Auto-crop a local display photo while preserving the original image locally
- Suggest clothing tags locally after photo capture or library selection
- Generate local outfit recommendations for daily office and meeting scenarios
- Save looks and record wear/like/dislike feedback
- Use Chinese or English automatically based on the device language

## Development

Open `ClosetPin.xcodeproj` in Xcode and run the `ClosetPin` scheme on an iOS simulator.

```sh
xcodebuild test -project ClosetPin.xcodeproj -scheme ClosetPin -destination 'platform=iOS Simulator,name=iPhone 17'
```

The project is also described by `project.yml` for regeneration with XcodeGen if needed.
