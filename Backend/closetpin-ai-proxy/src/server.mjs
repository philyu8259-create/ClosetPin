import http from "node:http";

const port = Number(process.env.PORT || 8791);
const dashscopeApiKey = process.env.DASHSCOPE_API_KEY || "";
const dashscopeBaseURL =
  process.env.DASHSCOPE_BASE_URL ||
  "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
const photoModel = process.env.CLOSETPIN_PHOTO_MODEL || "qwen3-vl-plus";
const explanationModel = process.env.CLOSETPIN_EXPLANATION_MODEL || "qwen-plus";
const maxBodyBytes = Number(process.env.MAX_BODY_BYTES || 6 * 1024 * 1024);
const requestTimeoutMs = Number(process.env.DASHSCOPE_TIMEOUT_MS || 14000);

const clothingTypes = new Set([
  "top",
  "bottom",
  "blazer",
  "shoes",
  "bag",
  "accessory",
  "outerwear",
]);
const seasonTags = new Set(["spring", "summer", "autumn", "winter"]);
const scenarioLabels = new Map([
  ["dailyOffice", "daily office"],
  ["importantMeeting", "important meeting"],
  ["weekendCasual", "weekend casual"],
  ["banquet", "banquet or dressed-up event"],
]);

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === "OPTIONS") {
      return sendJSON(response, 204, {});
    }

    const url = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);

    if (request.method === "GET" && url.pathname === "/health") {
      return sendJSON(response, 200, {
        ok: true,
        provider: "aliyun-dashscope",
        photoModel,
        explanationModel,
        configured: Boolean(dashscopeApiKey),
      });
    }

    if (!dashscopeApiKey) {
      return sendJSON(response, 503, { error: "dashscope_not_configured" });
    }

    if (request.method === "POST" && url.pathname === "/photo-tags") {
      const payload = await readJSON(request);
      const result = await suggestPhotoTags(payload);
      return sendJSON(response, 200, result);
    }

    if (request.method === "POST" && url.pathname === "/outfit-explanation") {
      const payload = await readJSON(request);
      const explanation = await explainOutfit(payload);
      return sendJSON(response, 200, { explanation });
    }

    return sendJSON(response, 404, { error: "not_found" });
  } catch (error) {
    const status = error.statusCode || 500;
    const errorCode = status >= 500 ? "upstream_unavailable" : "invalid_request";
    console.error(`[closetpin-ai] ${errorCode}:`, error.message);
    return sendJSON(response, status, { error: errorCode });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`[closetpin-ai] listening on 127.0.0.1:${port}`);
});

async function readJSON(request) {
  const chunks = [];
  let size = 0;

  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxBodyBytes) {
      const error = new Error("request body too large");
      error.statusCode = 413;
      throw error;
    }
    chunks.push(chunk);
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
  } catch {
    const error = new Error("invalid json");
    error.statusCode = 400;
    throw error;
  }
}

async function suggestPhotoTags(payload) {
  const imageJPEGBase64 = String(payload.imageJPEGBase64 || "").trim();
  if (!imageJPEGBase64) {
    const error = new Error("imageJPEGBase64 is required");
    error.statusCode = 400;
    throw error;
  }

  const content = await chatCompletion({
    model: photoModel,
    messages: [
      {
        role: "system",
        content: [
          "You are ClosetPin's clothing photo tagger.",
          "Return only compact JSON with these keys:",
          "type, color, seasons, formalityLevel, warmthLevel, confidence.",
          "type must be one of: top, bottom, blazer, shoes, bag, accessory, outerwear.",
          "seasons must use spring, summer, autumn, winter.",
          "formalityLevel and warmthLevel are integers from 1 to 5.",
          "confidence is a number from 0 to 1.",
          "Prefer simple English color names such as white, navy, black, beige, blue.",
        ].join(" "),
      },
      {
        role: "user",
        content: [
          {
            type: "image_url",
            image_url: {
              url: `data:image/jpeg;base64,${imageJPEGBase64}`,
            },
          },
          {
            type: "text",
            text: `Locale: ${safeString(payload.localeIdentifier, "en_US")}. Identify the clothing item from this image.`,
          },
        ],
      },
    ],
    max_tokens: 180,
  });

  return normalizePhotoTags(parseModelJSON(content));
}

async function explainOutfit(payload) {
  const scenario = safeString(payload.scenario, "dailyOffice");
  const items = Array.isArray(payload.items) ? payload.items.slice(0, 8) : [];
  if (items.length === 0) {
    const error = new Error("items are required");
    error.statusCode = 400;
    throw error;
  }

  const itemSummary = items
    .map((item) => ({
      type: safeString(item.type, "item"),
      color: safeString(item.color, "neutral"),
      seasons: Array.isArray(item.seasons) ? item.seasons.slice(0, 4) : [],
      formalityLevel: clampInteger(item.formalityLevel, 1, 5, 3),
      warmthLevel: clampInteger(item.warmthLevel, 1, 5, 3),
      status: safeString(item.status, "available"),
    }))
    .filter((item) => clothingTypes.has(item.type));

  const locale = safeString(payload.localeIdentifier, "en_US");
  const shouldUseChinese = locale.toLowerCase().startsWith("zh");
  const languageInstruction = shouldUseChinese
    ? "Use Simplified Chinese. One short, natural sentence. No more than 42 Chinese characters."
    : "Use English. One short, natural sentence. No more than 24 words.";

  const content = await chatCompletion({
    model: explanationModel,
    messages: [
      {
        role: "system",
        content: [
          "You explain ClosetPin outfit recommendations.",
          "ClosetPin already scored the outfit; do not claim that AI ranked it.",
          "Do not invent missing garments, brands, gender, body type, price, or weather.",
          "Return only JSON: {\"explanation\":\"...\"}.",
          languageInstruction,
        ].join(" "),
      },
      {
        role: "user",
        content: JSON.stringify({
          scenario: scenarioLabels.get(scenario) || scenario,
          score: clampInteger(payload.score, 0, 999, 0),
          items: itemSummary,
        }),
      },
    ],
    max_tokens: shouldUseChinese ? 90 : 70,
  });

  const parsed = parseModelJSON(content);
  const explanation = safeString(parsed.explanation, "").replace(/\s+/g, " ").trim();
  if (!explanation) {
    const error = new Error("empty explanation");
    error.statusCode = 502;
    throw error;
  }
  return explanation.slice(0, shouldUseChinese ? 90 : 180);
}

async function chatCompletion({ model, messages, max_tokens }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);

  try {
    const upstreamResponse = await fetch(dashscopeBaseURL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${dashscopeApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages,
        response_format: { type: "json_object" },
        max_tokens,
      }),
      signal: controller.signal,
    });

    const data = await upstreamResponse.json().catch(() => ({}));
    if (!upstreamResponse.ok) {
      const error = new Error(data?.error?.message || "dashscope request failed");
      error.statusCode = 502;
      throw error;
    }

    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      const error = new Error("dashscope returned empty content");
      error.statusCode = 502;
      throw error;
    }
    return content;
  } catch (error) {
    if (error.name === "AbortError") {
      const timeoutError = new Error("dashscope request timed out");
      timeoutError.statusCode = 504;
      throw timeoutError;
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function parseModelJSON(content) {
  const trimmed = content.trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    const error = new Error("model returned invalid json");
    error.statusCode = 502;
    throw error;
  }
}

function normalizePhotoTags(raw) {
  const type = clothingTypes.has(raw.type) ? raw.type : "top";
  const seasons = Array.isArray(raw.seasons)
    ? raw.seasons.filter((season) => seasonTags.has(season)).slice(0, 4)
    : [];

  return {
    type,
    color: safeString(raw.color, "neutral").toLowerCase().slice(0, 32),
    seasons: seasons.length > 0 ? seasons : ["spring", "autumn"],
    formalityLevel: clampInteger(raw.formalityLevel, 1, 5, 3),
    warmthLevel: clampInteger(raw.warmthLevel, 1, 5, 3),
    confidence: clampNumber(raw.confidence, 0, 1, 0.65),
  };
}

function safeString(value, fallback) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function clampInteger(value, min, max, fallback) {
  const number = Number.parseInt(value, 10);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(Math.max(number, min), max);
}

function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(Math.max(number, min), max);
}

function sendJSON(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });

  if (statusCode === 204) {
    response.end();
    return;
  }

  response.end(JSON.stringify(payload));
}
