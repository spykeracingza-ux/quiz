// Quizillion API — Cloudflare Worker + D1. Static files are served from ./public.
const AGES = ["kids", "juniors", "teens", "adults"];
const MAX_SCORE = 350;

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json" } });
const bad = (msg, status = 400) => json({ error: msg }, status);

function rand(n = 24) {
  const b = crypto.getRandomValues(new Uint8Array(n));
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}
async function hashPin(pin, salt) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pin), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: new TextEncoder().encode(salt), iterations: 100000 }, key, 256);
  return [...new Uint8Array(bits)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
const publicPlayer = (r) => ({
  id: r.id, name: r.name, age: r.age, best: r.best, days: r.days, streak: r.streak,
  lastDay: r.last_day, todayScore: r.today_score, todayGrid: r.today_grid,
});
function dayOk(day) {
  // Accept the player's local date if it's within a day of UTC today.
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day || "")) return false;
  const diff = Math.abs(Date.parse(day) - Date.parse(new Date().toISOString().slice(0, 10)));
  return diff <= 864e5;
}
const prevDay = (day) => new Date(Date.parse(day) - 864e5).toISOString().slice(0, 10);

async function authed(req, env) {
  const t = (req.headers.get("authorization") || "").replace(/^Bearer /, "");
  if (!t) return null;
  return env.DB.prepare(
    "SELECT p.* FROM sessions s JOIN players p ON p.id = s.player_id WHERE s.token = ?"
  ).bind(t).first();
}

async function tooManyFails(env, id) {
  const r = await env.DB.prepare(
    "SELECT COUNT(*) n FROM login_fails WHERE player_id = ? AND at > ?"
  ).bind(id, Date.now() - 15 * 60e3).first();
  return r.n >= 8;
}

async function handleApi(req, env, url) {
  const path = url.pathname;
  const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};

  if (path === "/api/signup") {
    const { name, pin, age } = body;
    if (!/^[a-zA-Z0-9_-]{3,16}$/.test(name || "")) return bad("Username: 3–16 letters, numbers, _ or -");
    if (!/^\d{4}$/.test(pin || "")) return bad("PIN must be 4 digits");
    if (!AGES.includes(age)) return bad("Pick your age group");
    const id = name.toLowerCase();
    if (await env.DB.prepare("SELECT 1 FROM players WHERE id = ?").bind(id).first())
      return bad("That username is taken — try another", 409);
    const salt = rand(12);
    await env.DB.prepare(
      "INSERT INTO players (id, name, pin_hash, salt, age, created) VALUES (?, ?, ?, ?, ?, ?)"
    ).bind(id, name, await hashPin(pin, salt), salt, age, Date.now()).run();
    const token = rand();
    await env.DB.prepare("INSERT INTO sessions (token, player_id, created) VALUES (?, ?, ?)").bind(token, id, Date.now()).run();
    const p = await env.DB.prepare("SELECT * FROM players WHERE id = ?").bind(id).first();
    return json({ token, player: publicPlayer(p) });
  }

  if (path === "/api/login") {
    const id = String(body.name || "").toLowerCase();
    const p = await env.DB.prepare("SELECT * FROM players WHERE id = ?").bind(id).first();
    if (p && (await tooManyFails(env, id))) return bad("Too many tries — wait 15 minutes", 429);
    if (!p || (await hashPin(String(body.pin || ""), p.salt)) !== p.pin_hash) {
      if (p) await env.DB.prepare("INSERT INTO login_fails (player_id, at) VALUES (?, ?)").bind(id, Date.now()).run();
      return bad("Username or PIN doesn't match", 401);
    }
    const token = rand();
    await env.DB.prepare("INSERT INTO sessions (token, player_id, created) VALUES (?, ?, ?)").bind(token, id, Date.now()).run();
    return json({ token, player: publicPlayer(p) });
  }

  if (path === "/api/leaderboard") {
    const age = url.searchParams.get("age"), day = url.searchParams.get("day");
    if (!AGES.includes(age) || !dayOk(day)) return bad("Bad request");
    const { results } = await env.DB.prepare(
      "SELECT * FROM players WHERE age = ? AND last_day = ? AND today_score IS NOT NULL ORDER BY today_score DESC LIMIT 10"
    ).bind(age, day).all();
    return json({ rows: results.map(publicPlayer) });
  }

  const me = await authed(req, env);
  if (!me) return bad("Please log in", 401);

  if (path === "/api/me") return json({ player: publicPlayer(me) });

  if (path === "/api/logout") {
    await env.DB.prepare("DELETE FROM sessions WHERE token = ?")
      .bind((req.headers.get("authorization") || "").replace(/^Bearer /, "")).run();
    return json({ ok: true });
  }

  if (path === "/api/age") {
    if (!AGES.includes(body.age)) return bad("Bad age group");
    await env.DB.prepare("UPDATE players SET age = ? WHERE id = ?").bind(body.age, me.id).run();
    return json({ player: publicPlayer({ ...me, age: body.age }) });
  }

  if (path === "/api/score") {
    const { score, grid, day } = body;
    if (!dayOk(day)) return bad("Bad date");
    if (!Number.isInteger(score) || score < 0 || score > MAX_SCORE) return bad("Bad score");
    if (me.last_day === day) return bad("Already played today", 409);
    const streak = me.last_day === prevDay(day) ? me.streak + 1 : 1;
    const g = String(grid || "").slice(0, 40);
    await env.DB.prepare(
      "UPDATE players SET last_day = ?, today_score = ?, today_grid = ?, streak = ?, days = days + 1, best = MAX(best, ?) WHERE id = ?"
    ).bind(day, score, g, streak, score, me.id).run();
    const p = await env.DB.prepare("SELECT * FROM players WHERE id = ?").bind(me.id).first();
    return json({ player: publicPlayer(p) });
  }

  return bad("Not found", 404);
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname.startsWith("/api/")) {
      try { return await handleApi(req, env, url); }
      catch (e) { return bad("Server error", 500); }
    }
    return env.ASSETS.fetch(req);
  },
};
