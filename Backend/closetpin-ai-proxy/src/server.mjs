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
const supportEmail = "support@xufanzhilian.com";
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
function normalizePath(pathname) {
  if (pathname !== "/" && pathname.endsWith("/")) {
    return pathname.replace(/\/+$/u, "");
  }
  return pathname;
}

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === "OPTIONS") {
      return sendJSON(response, 204, {});
    }

    const url = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);
    const path = normalizePath(url.pathname);

    if (request.method === "GET" && (path === "/health" || path === "/closetpin/health")) {
      return sendJSON(response, 200, {
        ok: true,
        provider: "aliyun-dashscope",
        photoModel,
        explanationModel,
        configured: Boolean(dashscopeApiKey),
      });
    }

    if (
      request.method === "GET" &&
      (path === "/closetpin/privacy" || path === "/privacy" || path === "/closetpin/en/privacy")
    ) {
      return sendHTML(response, 200, buildPrivacyPageHTML("en"));
    }

    if (request.method === "GET" && (path === "/closetpin/zh/privacy" || path === "/zh/privacy")) {
      return sendHTML(response, 200, buildPrivacyPageHTML("zh"));
    }

    if (
      request.method === "GET" &&
      (path === "/closetpin/support" || path === "/support" || path === "/closetpin/en/support")
    ) {
      return sendHTML(response, 200, buildSupportPageHTML("en"));
    }

    if (request.method === "GET" && (path === "/closetpin/zh/support" || path === "/zh/support")) {
      return sendHTML(response, 200, buildSupportPageHTML("zh"));
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

function legalPageShell({ lang, title, body }) {
  return `<!DOCTYPE html>
<html lang="${lang}">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
    <style>
      body {
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        line-height: 1.7;
        color: #222;
        background: #fbf8f1;
      }
      main { max-width: 860px; margin: 0 auto; padding: 32px 20px 44px; }
      h1 { margin: 0 0 4px; font-size: 32px; }
      h2 { margin-top: 28px; font-size: 22px; }
      p { margin: 10px 0; }
      ul { padding-left: 22px; }
      li { margin: 8px 0; }
      .section { margin-top: 18px; }
      .contact { font-weight: 600; }
      .subtle { color: #555; }
      footer { margin-top: 28px; font-size: 13px; color: #666; }
      a { color: #1f6b60; }
    </style>
  </head>
  <body>
    <main>${body}</main>
  </body>
</html>`;
}

function buildPrivacyPageHTML(locale) {
  if (locale === "zh") {
    return legalPageShell({
      lang: "zh-Hans",
      title: "衣橱钉隐私政策",
      body: `
      <h1>衣橱钉隐私政策</h1>
      <p class="subtle">最后更新：2026 年 6 月 27 日</p>
      <div class="section">
        <h2>1）默认本地保存照片</h2>
        <p>衣橱钉会优先把你的衣物照片、穿搭记录和相关衣橱数据保存在你的设备本地。我们不会自动上传你的完整相册。</p>
      </div>
      <div class="section">
        <h2>2）云端 AI 识别范围</h2>
        <ul>
          <li>当你开启或使用云端识别时，只会上传当前正在识别的那一张衣物照片。</li>
          <li>衣橱钉不会上传完整相册，也不会上传与当前识别无关的文件。</li>
          <li>为完成识别，可能会发送必要的最少上下文，例如当前界面语言或用户选择的场景。</li>
        </ul>
      </div>
      <div class="section">
        <h2>3）天气功能权限</h2>
        <p>天气功能仅在你授权位置权限后使用定位信息，或在你手动输入城市后根据该城市提供穿搭参考。</p>
      </div>
      <div class="section">
        <h2>4）订阅与支付</h2>
        <p>订阅购买、账单、续订和退款由 Apple 通过 App Store 及你的 Apple 账户管理。</p>
      </div>
      <div class="section">
        <h2>5）不会出售个人数据</h2>
        <p>衣橱钉不会向第三方出售你的个人数据。</p>
      </div>
      <div class="section">
        <h2>6）联系我们</h2>
        <p>隐私、数据或账户相关问题，请联系：<span class="contact">${supportEmail}</span>。</p>
      </div>
      <footer>
        <p>如果你不希望某张照片使用云端 AI 识别，可以跳过该功能，并继续使用本地流程。</p>
      </footer>`,
    });
  }

  return legalPageShell({
    lang: "en",
    title: "ClosetPin Privacy Policy",
    body: `
      <h1>ClosetPin Privacy Policy</h1>
      <p class="subtle">Last updated: June 27, 2026</p>
      <div class="section">
        <h2>1) Local photo storage by default</h2>
        <p>ClosetPin stores your wardrobe and avatar photos on your device first. We keep this by default and do not upload your photo albums automatically.</p>
      </div>
      <div class="section">
        <h2>2) Cloud AI recognition scope</h2>
        <ul>
          <li>When cloud recognition is enabled, only the current photo being analyzed is uploaded.</li>
          <li>ClosetPin does not upload full albums or unrelated files.</li>
          <li>Only necessary app context is sent (for example, current interface language and minimal context needed for recognition).</li>
        </ul>
      </div>
      <div class="section">
        <h2>3) Weather feature permissions</h2>
        <p>Weather data is only used after you allow location permission, or when you manually enter a city.</p>
      </div>
      <div class="section">
        <h2>4) Subscriptions and billing</h2>
        <p>Subscription purchase, billing, and renewal are managed by Apple through App Store in-app purchase and your Apple account.</p>
      </div>
      <div class="section">
        <h2>5) No data sale</h2>
        <p>ClosetPin does not sell your personal data to third parties.</p>
      </div>
      <div class="section">
        <h2>6) Contact support</h2>
        <p>For privacy, data, or account requests: <span class="contact">${supportEmail}</span>.</p>
      </div>
      <footer>
        <p>If you do not want cloud AI recognition for a photo, you can skip that feature and continue using local-only flows.</p>
      </footer>`,
  });
}

function buildSupportPageHTML(locale) {
  if (locale === "zh") {
    return legalPageShell({
      lang: "zh-Hans",
      title: "衣橱钉支持",
      body: `
      <h1>衣橱钉支持</h1>
      <div class="section">
        <h2>邮箱支持</h2>
        <p>如需帮助，请联系：<span class="contact">${supportEmail}</span>。</p>
      </div>
      <div class="section">
        <h2>订阅 / 恢复购买</h2>
        <ul>
          <li>订阅购买和恢复购买由 Apple App Store 管理。</li>
          <li>请确认当前 App Store 登录的 Apple ID 与购买时使用的 Apple ID 一致。</li>
          <li>如果恢复失败，请等待几分钟后重试；仍有问题可联系支持邮箱，并附上可用的 Apple 收据信息。</li>
        </ul>
      </div>
      <div class="section">
        <h2>AI 识别</h2>
        <ul>
          <li>拍摄衣物时，请尽量使用充足光线和简洁背景。</li>
          <li>如果上传经常失败，可以尝试重新拍摄或裁成更清晰的竖图/方图。</li>
          <li>请确认已允许衣橱钉访问相机和照片。</li>
        </ul>
      </div>
      <div class="section">
        <h2>天气</h2>
        <ul>
          <li>授权定位后可以使用自动城市；也可以手动输入城市。</li>
          <li>如果天气不准确，请检查设备时间、定位权限和网络状态。</li>
        </ul>
      </div>
      <div class="section">
        <h2>照片处理 / 排查</h2>
        <ul>
          <li>确认图片格式受支持，并且文件大小在 App 限制内。</li>
          <li>重新打开 App 后再拍摄或上传一次。</li>
          <li>确认本地存储空间充足，并使用当前版本的 App。</li>
        </ul>
      </div>`,
    });
  }

  return legalPageShell({
    lang: "en",
    title: "ClosetPin Support",
    body: `
      <h1>ClosetPin Support</h1>
      <div class="section">
        <h2>Email</h2>
        <p>Contact support at <span class="contact">${supportEmail}</span>.</p>
      </div>
      <div class="section">
        <h2>Subscription / Restore Purchase</h2>
        <ul>
          <li>All subscription purchases and restorations are managed by Apple App Store.</li>
          <li>To restore, open your device settings and ensure Apple ID used in App Store matches the one used at purchase.</li>
          <li>If restore fails, wait a few minutes and try again; then contact support with the Apple receipt ID if available.</li>
        </ul>
      </div>
      <div class="section">
        <h2>AI Recognition</h2>
        <ul>
          <li>Keep clothes in good daylight and clear background when taking photos.</li>
          <li>Use square or vertical crop if the upload is rejected frequently.</li>
          <li>Check if “Allow ClosetPin to access photos / camera” is enabled.</li>
        </ul>
      </div>
      <div class="section">
        <h2>Weather</h2>
        <ul>
          <li>Grant location permission to use automatic city detection, or enter a city manually.</li>
          <li>If weather is inaccurate, verify your device time and location permission.</li>
          <li>Refresh on a stable network.</li>
        </ul>
      </div>
      <div class="section">
        <h2>Photo Processing / Troubleshooting</h2>
        <ul>
          <li>Make sure image format is supported and file size is within app limits.</li>
          <li>Reopen the app and retake the photo before retrying upload.</li>
          <li>Ensure you are using a stable network and the current app version.</li>
          <li>If photos are not saved, check app storage permissions and local storage space.</li>
        </ul>
      </div>`,
  });
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

function sendHTML(response, statusCode, html) {
  response.writeHead(statusCode, {
    "Content-Type": "text/html; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  response.end(html);
}
