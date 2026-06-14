// Balance Tower — бэкенд рекордов на Cloudflare Workers + D1.
//
// Маршруты:
//   POST /api/score        { initData, score }  -> сохраняет лучший счёт
//   GET  /api/leaderboard                       -> топ-10
//
// Безопасность: счёт принимается только с валидной подписью Telegram WebApp
// (initData проверяется HMAC по токену бота). Без этого любой мог бы прислать
// произвольный рекорд.

const MAX_SCORE = 100000; // защита от заведомо абсурдных значений

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = corsHeaders(env);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: cors });
    }

    try {
      if (url.pathname === "/api/score" && request.method === "POST") {
        return await handleScore(request, env, cors);
      }
      if (url.pathname === "/api/leaderboard" && request.method === "GET") {
        return await handleLeaderboard(env, cors);
      }
      return json({ error: "not found" }, 404, cors);
    } catch (err) {
      return json({ error: "server error", detail: String(err) }, 500, cors);
    }
  },
};

async function handleScore(request, env, cors) {
  const body = await request.json().catch(() => null);
  if (!body || typeof body.initData !== "string" || typeof body.score !== "number") {
    return json({ error: "bad request" }, 400, cors);
  }

  const user = await verifyInitData(body.initData, env.BOT_TOKEN);
  if (!user) {
    return json({ error: "invalid signature" }, 401, cors);
  }

  const score = Math.floor(body.score);
  if (!Number.isFinite(score) || score < 0 || score > MAX_SCORE) {
    return json({ error: "bad score" }, 400, cors);
  }

  const now = Math.floor(Date.now() / 1000);
  const username = user.username || user.first_name || "player";

  // Обновляем только если новый счёт выше сохранённого лучшего.
  await env.DB.prepare(
    `INSERT INTO scores (user_id, username, best_score, updated_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       username = excluded.username,
       best_score = MAX(scores.best_score, excluded.best_score),
       updated_at = excluded.updated_at`
  ).bind(user.id, username, score, now).run();

  const row = await env.DB.prepare(
    `SELECT best_score FROM scores WHERE user_id = ?`
  ).bind(user.id).first();

  return json({ ok: true, best: row ? row.best_score : score }, 200, cors);
}

async function handleLeaderboard(env, cors) {
  const { results } = await env.DB.prepare(
    `SELECT username, best_score FROM scores ORDER BY best_score DESC LIMIT 10`
  ).all();
  return json({ leaderboard: results || [] }, 200, cors);
}

// --- Проверка подписи Telegram WebApp initData ---
// https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
async function verifyInitData(initData, botToken) {
  if (!botToken) return null;
  const params = new URLSearchParams(initData);
  const hash = params.get("hash");
  if (!hash) return null;
  params.delete("hash");

  const pairs = [];
  for (const [k, v] of params) pairs.push(`${k}=${v}`);
  pairs.sort();
  const dataCheckString = pairs.join("\n");

  // secret_key = HMAC_SHA256(key="WebAppData", message=bot_token)
  const secretKey = await hmac(strBytes("WebAppData"), strBytes(botToken));
  // computed = HMAC_SHA256(key=secret_key, message=data_check_string)
  const computed = await hmac(secretKey, strBytes(dataCheckString));
  const computedHex = toHex(computed);

  if (computedHex !== hash) return null;

  // Свежесть: не старше 24 часов.
  const authDate = parseInt(params.get("auth_date") || "0", 10);
  if (!authDate || Math.floor(Date.now() / 1000) - authDate > 86400) return null;

  const userRaw = params.get("user");
  if (!userRaw) return null;
  try {
    const u = JSON.parse(userRaw);
    if (!u || typeof u.id !== "number") return null;
    return u;
  } catch {
    return null;
  }
}

async function hmac(keyBytes, msgBytes) {
  const key = await crypto.subtle.importKey(
    "raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, msgBytes);
  return new Uint8Array(sig);
}

function strBytes(s) {
  return new TextEncoder().encode(s);
}

function toHex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function corsHeaders(env) {
  return {
    "Access-Control-Allow-Origin": env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}
