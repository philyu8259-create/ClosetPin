# Cloud Photo Recognition Contract

ClosetPin keeps photo recognition local by default. When the user enables cloud photo recognition, the iOS app can POST the current clothing photo to a configured backend URL.

## iOS Configuration

Release builds use `https://xufanzhilian.com/api/closetpin/photo-tags`. In Debug builds, set `CLOSETPIN_CLOUD_PHOTO_RECOGNITION_URL` in the process environment to test a backend endpoint manually.

Production builds currently point to `https://xufanzhilian.com/api/closetpin/photo-tags`, which is backed by the ClosetPin AI proxy and Alibaba Cloud Model Studio / DashScope. The app never stores the DashScope API key.

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

## Outfit Explanation

Release builds use `https://xufanzhilian.com/api/closetpin/outfit-explanation`. In Debug builds, set `CLOSETPIN_AI_RECOMMENDATION_EXPLANATION_URL` in the process environment to test a backend endpoint manually.

The app posts only the current recommended outfit metadata:

```json
{
  "candidateId": "dailyOffice|seed",
  "scenario": "dailyOffice",
  "score": 142,
  "explanationSeed": "seed",
  "localeIdentifier": "zh_Hans",
  "items": [
    {
      "type": "top",
      "color": "white",
      "seasons": ["spring"],
      "formalityLevel": 3,
      "warmthLevel": 2,
      "status": "available"
    }
  ]
}
```

The backend responds with:

```json
{
  "explanation": "白衬衫配海军蓝下装，利落又适合今天的场合。"
}
```
