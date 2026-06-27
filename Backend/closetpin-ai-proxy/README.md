# ClosetPin AI Proxy

Small backend proxy for ClosetPin's China AI integration. It keeps the DashScope API key on the server and exposes the two iOS-facing endpoints already used by the app.

## Endpoints

- `POST /photo-tags`
- `POST /outfit-explanation`
- `GET /health`
- `GET /closetpin/en/privacy`
- `GET /closetpin/zh/privacy`
- `GET /closetpin/en/support`
- `GET /closetpin/zh/support`

When deployed behind `xufanzhilian.com`, Nginx maps these to:

- `https://xufanzhilian.com/api/closetpin/photo-tags`
- `https://xufanzhilian.com/api/closetpin/outfit-explanation`
- `https://xufanzhilian.com/api/closetpin/health`
- `https://xufanzhilian.com/closetpin/en/privacy`
- `https://xufanzhilian.com/closetpin/zh/privacy`
- `https://xufanzhilian.com/closetpin/en/support`
- `https://xufanzhilian.com/closetpin/zh/support`

## Environment

```sh
PORT=8791
DASHSCOPE_API_KEY=sk-...
CLOSETPIN_PHOTO_MODEL=qwen3-vl-plus
CLOSETPIN_EXPLANATION_MODEL=qwen-plus
```

Do not commit real keys.

## Deployment Notes

- Locale-specific legal/support pages can be checked without the AI backend key.
- Use English URLs for App Store Connect `en-US` metadata and Simplified Chinese URLs for `zh-Hans` metadata.
- `Nginx` should proxy `/api/closetpin/` to `http://127.0.0.1:8791/` (existing project config already does this).
- Keep API keys only in `EnvironmentFile` or secret config of your host; do not print them in logs.
