# Brainwave — deploy to Cloudflare

Needs Node.js and a Cloudflare account. Run these from this folder.

```bash
npx wrangler login
npx wrangler d1 create quizillion
#   -> copy the database_id it prints into wrangler.toml
npx wrangler d1 execute quizillion --remote --file=schema.sql
npx wrangler deploy
```

The site goes live at `https://quiz.<your-subdomain>.workers.dev`.

**Custom domain:** in the Cloudflare dashboard, open Workers & Pages → quiz → Settings → Domains & Routes → Add → Custom domain.

**Run locally first (optional):**
```bash
npx wrangler d1 execute quizillion --local --file=schema.sql
npx wrangler dev
```

## What's inside
- `public/index.html` — the game (questions, scoring, UI)
- `src/worker.js` — API: sign up, log in (PINs hashed with PBKDF2, lockout after 8 wrong tries in 15 min), age group, daily score (one per day, max 350), leaderboard
- `schema.sql` — D1 tables
