# VDB Diwali Triathlon

Three Diwali mini-games (Diya Keeper, Firework Frenzy, Rangoli Recall) played back to back, with a shared
top-5 leaderboard stored in Supabase. Anyone with the link can play; no sign-in needed.

## Files

| File | What it is |
|---|---|
| `index.html` | The whole game |
| `config.js` | Your Supabase project URL and public (anon) key |
| `diwali-gurgaon.jpg` | Background photo |
| `supabase/schema.sql` | Database setup: the scores table and the four functions the game calls |

## 1. Set up Supabase (once)

1. Create a free project at supabase.com.
2. Open **SQL Editor → New query**, paste all of `supabase/schema.sql`, and click **Run**.
3. Open **Project Settings → API** and copy:
   - **Project URL** (looks like `https://abcd1234.supabase.co`)
   - **anon public** key
4. Paste both into `config.js`.

Use only the **anon public** key. Never put the `service_role` key in this project.

### How scores are kept safe

- The browser can't read or edit the scores table directly. Row level security is on and there are no policies.
- The game can only call four functions: `top_scores`, `my_standing`, `post_score` and `rename_player`.
- `post_score` checks each game's score, adds up the total on the server, and allows one post per player
  every 15 seconds.
- Each browser gets a private player id. It's never shown on the leaderboard, so nobody can post or rename
  as someone else.
- The leaderboard shows each player's best run.

## 2. Deploy on Vercel

This is a static site, so no build step is needed.

- **From GitHub:** push this folder to a repo, then in Vercel choose **Add New → Project**, import the
  repo and click **Deploy** (Framework preset: Other).
- **From this computer:** `npx vercel` in this folder, then `npx vercel --prod`.

After the first deploy, put the public link in `config.js` as `gameUrl` so the "Copy a challenge"
message uses it, and redeploy.

## Managing the leaderboard

In Supabase, go to **Table Editor → scores**. You can delete a row there to remove a silly name or a
suspicious score. To reset the whole board, run `truncate public.scores;` in the SQL Editor.
