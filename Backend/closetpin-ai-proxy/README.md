# ClosetPin AI Proxy

Small backend proxy for ClosetPin's China AI integration. It keeps the DashScope API key on the server and exposes the two iOS-facing endpoints already used by the app.

## Endpoints

- `POST /photo-tags`
- `POST /outfit-explanation`
- `GET /health`

When deployed behind `xufanzhilian.com`, Nginx maps these to:

- `https://xufanzhilian.com/api/closetpin/photo-tags`
- `https://xufanzhilian.com/api/closetpin/outfit-explanation`

## Environment

```sh
PORT=8791
DASHSCOPE_API_KEY=sk-...
CLOSETPIN_PHOTO_MODEL=qwen3-vl-plus
CLOSETPIN_EXPLANATION_MODEL=qwen-plus
```

Do not commit real keys.
