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
| `test/` | The headless test run. 132 assertions. |

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
node run.js      # 132 assertions
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

## Signing up and joining a company

A new man taps **New here? Create an account** (name, email, password).
He then lands on "Nearly there", which has one box that takes either code
the office can give him:

- **Company code** (`K7M4QX`, six characters, reusable). Shown to admins in
  the office portal under People, to pin up in the site cabin. Typing it
  sends a *join request* (`request_to_join`, migration 0013) that only that
  company's admins can see. He waits on "Waiting to be let in", which
  checks every 20 seconds while it's on screen and moves him into the app
  by itself once approved. Declined, he is told so with the firm's name.
- **Invite code** (`MPG-AB3D-7KQ2`, single use). Lets him straight in with
  the role it was made for (`redeem_role_invite`). No approval.

The box tells them apart by shape and is forgiving to type:
`k7m 4qx`, `ab3d 7kq2` and `mpg-ab3d-7kq2` all work.

The office decides in the portal: **People → Waiting to join**, with a
role picker, **Approve** and **Decline**. The iPhone app's Manage → Team
"Add to company" approves the same requests.

The phone never sends a company id or a role. It learns its company by
reloading its own profile after the server has decided.

If the Supabase project has email confirmation on, sign-up tells him to
check his email and sign in afterwards; the link comes back to this app,
so this URL must be in Authentication → URL Configuration → Redirect URLs.

## Known limits

- Reads of older photos need a signed URL, so thumbnails of already-
  uploaded photos need signal. Photos taken and not yet sent are shown
  from the phone.
- The password-reset link only works if this app's URL is registered
  under Supabase → Authentication → URL Configuration → Redirect URLs.
- Site-manager and admin work is not here. That is still the office
  portal.
