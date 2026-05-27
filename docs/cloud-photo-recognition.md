# Cloud Photo Recognition Contract

ClosetPin keeps photo recognition local by default. When the user enables cloud photo recognition, the iOS app can POST the current clothing photo to a configured backend URL.

## iOS Configuration

Set `CLOSETPIN_CLOUD_PHOTO_RECOGNITION_URL` to the backend endpoint URL. In Debug builds, the app also reads this value from the process environment.

If no endpoint is configured, the app silently falls back to local photo tag suggestions.

## Request

`POST /v1/clothing-photo-tags`

```json
{
  "imageJPEGBase64": "<compressed-current-clothing-photo>",
  "localeIdentifier": "en_US"
}
```

The app does not send closet items, saved outfits, preferences, notes, storage locations, or user history.

## Response

```json
{
  "type": "shoes",
  "color": "black",
  "seasons": ["autumn", "winter"],
  "formalityLevel": 4,
  "warmthLevel": 2,
  "confidence": 0.82
}
```

Supported `type` values: `top`, `bottom`, `blazer`, `shoes`, `bag`, `accessory`, `outerwear`.

Supported `seasons` values: `spring`, `summer`, `autumn`, `winter`.

The app clamps `formalityLevel`, `warmthLevel`, and `confidence` to valid ranges and ignores unsupported seasons.
