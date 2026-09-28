# MY Site — the crew app

The phone app for the men on site, as a web page. Same Supabase project,
same row-level security, same rows as the iOS app — a second front door
onto the house that is already built.

It exists because roughly half the crew are on Android and cannot install
the iOS build.

## What is here

| File | What it is |
|---|---|
| `index.html` | The whole app. One file — HTML, CSS and JavaScript together, no build step, same as the office portal. |
| `sw.js` | Service worker. Caches the shell so the app opens with no signal. It never caches Supabase. |
| `manifest.webmanifest` | Makes it installable. Bump nothing here without bumping `CACHE` in `sw.js`. |
| `icon-*.png` | Home-screen icons, cut from the iOS app icon so both look the same on a shelf. |
| `test/` | The headless test run. 106 assertions. |

## The URL

Deployed at the `crew/` path of whatever GitHub Pages serves, so:

```
https://steveybarnes-cell.github.io/my-site/crew/
```

Everything is relative — `./sw.js`, `./manifest.webmanifest` — so moving
the folder moves the app without editing anything.

## Deploying a change

1. Edit `index.html`.
2. **Bump `CACHE` in `sw.js`** — `mysite-crew-v1` → `v2`. This is the only
   thing that evicts an old shell. A crew phone that never clears its
   cache will otherwise run last month's app for as long as it stays
   installed.
3. `node --check` the script. It is one file, and one stray character
   kills every function in it.
4. `cd test && node run.js` — must be green.
5. Commit and push.

## Testing

```bash
cd test
npm install
node run.js      # 106 assertions
node shots.js    # screenshots of every screen into ../shots/
```

The tests run against a stand-in backend (`fake-supabase.js`) that speaks
GoTrue, PostgREST and Storage, and records every request the app makes.
That is the point: asserting on the screen proves nothing about the row
that reaches the database, so every write is checked at both ends.

What the tests cannot prove is that the real Supabase accepts those rows.
That check has to run somewhere with network to the live project.

## Rules this app keeps

- **Publishable key only.** The `service_role` key is not here and must
  never be. Anything needing elevated rights goes in an edge function.
- **No client ever sends a `company_id`.** Every table defaults it to
  `current_company_id()` on the server. The one place the app touches a
  company id is building a storage path, and that value comes from the
  signed-in user's own profile row.
- **Storage paths are three segments** — `company/site/owner/file`, all
  lower case — because the storage policy parses them that way and
  refuses anything else on insert.
- **Location is read once per clock tap and at no other time.** No
  watcher, no background permission, no geofence monitoring. A web page
  cannot track a phone it is not open on, and that is a promise made to
  the men using this.
- **Work lines are voided, never deleted.** The offline queue only speaks
  upsert, and a week that has been invoiced must still show what it was
  built from.

## Joining a company

A man who signs up and isn't in a company yet lands on "Nearly there".
There are two ways off it:

- **An invite code.** The office makes one in the portal
  (`create_role_invite`, any role since 0005) and reads or texts it to him.
  He types it in; `redeem_role_invite` checks it, attaches him to that
  company and sets his role in one server call. The phone sends only the
  code — it learns its company by reloading its own profile afterwards.
  Codes are forgiving to type: `ab3d 7kq2`, `MPGAB3D7KQ2` and
  `mpg-ab3d-7kq2` all become `MPG-AB3D-7KQ2`.
- **The office adopts him** (`adopt_user_into_company`) and he taps
  *Check again*.

Starting a new company (`create_company`, 0009) is deliberately not here —
that is the office's first step, not a crew one.

## Known limits

- Reads of older photos need a signed URL, so thumbnails of already-
  uploaded photos need signal. Photos taken and not yet sent are shown
  from the phone.
- The password-reset link only works if this app's URL is registered
  under Supabase → Authentication → URL Configuration → Redirect URLs.
- Site-manager and admin work is not here. That is still the office
  portal.
