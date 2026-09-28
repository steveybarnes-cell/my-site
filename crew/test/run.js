/* =====================================================================
   Headless verification of the crew app.

   What this can prove: the arithmetic, the offline queue, the geofence
   maths, the shape of every row that leaves the phone, and that nothing
   here sends a company_id it invented. What it cannot prove: that the
   real Supabase accepts those rows. That test has to run somewhere with
   network to the real project.

   Assertions are made at both ends — the screen AND the request the app
   sent. A CSS edit once matched nothing on this project and reported
   success; a test that only reads the DOM is the same mistake wearing a
   different hat.
   ===================================================================== */

"use strict";

const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");
const { makeBackend } = require("./fake-supabase");

const APP_DIR = path.resolve(__dirname, "..");
const PORT = 8788;
const BASE = "http://localhost:" + PORT + "/";

/* ---------- a static server, because file:// has no origin and so no
     localStorage, no service worker and no IndexedDB worth the name ---------- */

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".webmanifest": "application/manifest+json",
  ".png": "image/png"
};
function serve() {
  return new Promise(resolve => {
    const s = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split("?")[0]);
      if (p === "/") p = "/index.html";
      const file = path.join(APP_DIR, p);
      if (!file.startsWith(APP_DIR) || !fs.existsSync(file)) {
        res.writeHead(404); res.end("no"); return;
      }
      res.writeHead(200, {
        "Content-Type": MIME[path.extname(file)] || "application/octet-stream",
        "Service-Worker-Allowed": "/"
      });
      res.end(fs.readFileSync(file));
    });
    s.listen(PORT, () => resolve(s));
  });
}

/* ---------- the world the app wakes up in ---------- */

const ME = {
  id: "11111111-1111-4111-8111-111111111111",
  company_id: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",   // deliberately upper case
  name: "Dave Sturrock", email: "dave@example.co.uk", role: "Tradesman", active: true
};
/* Someone else in the same company. An Admin can read this row, so if
   the app ever asks for "a profile" rather than "my profile" it will
   open as this man. */
const OTHER = {
  id: "00000000-0000-4000-8000-000000000000",
  company_id: ME.company_id, name: "Alan Other", email: "alan@example.co.uk",
  role: "Tradesman", active: true
};
const SITE_A = {
  id: "22222222-2222-4222-8222-222222222222", name: "Marlborough Road",
  address: "12 Marlborough Rd", status: "Active",
  latitude: 51.5007, longitude: -0.1246, geofence_radius: 150
};
const SITE_B = {
  id: "33333333-3333-4333-8333-333333333333", name: "Clifton Gardens",
  address: "4 Clifton Gdns", status: "Active",
  latitude: 51.4800, longitude: -0.1000, geofence_radius: 100
};
function todayISO() {
  const d = new Date(), p = n => String(n).padStart(2, "0");
  return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
}
const ALLOC = {
  id: "44444444-4444-4444-8444-444444444444",
  site_id: SITE_A.id, tradesman_id: ME.id, date: todayISO(),
  task_description: "Second fix, plots 3 and 4", trade: "Carpenter",
  category: "Contract Work", status: "Allocated", percent_complete: 0,
  progress_note: "", notes: "", start_time: "08:00"
};

/* ---------- assertions ---------- */

let passed = 0;
const failures = [];
function check(name, condition, detail) {
  if (condition) { passed++; console.log("  ok   " + name); }
  else {
    failures.push(name + (detail ? "  →  " + detail : ""));
    console.log("  FAIL " + name + (detail ? "  →  " + detail : ""));
  }
}
function section(t) { console.log("\n" + t); }

/* ---------- helpers ---------- */

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function waitFor(fn, ms) {
  const until = Date.now() + (ms || 5000);
  for (;;) {
    if (await fn()) return true;
    if (Date.now() > until) return false;
    await sleep(60);
  }
}
const text = (page, sel) => page.$eval(sel, n => n.innerText).catch(() => "");

/* Every write in this app is queued and flushed, so "did it reach the
   backend" is a question with a delay in it. Asserting the instant after
   a tap tests the test's own timing, not the app. */
const landed = (fn, ms) => waitFor(async () => {
  try { return !!fn(); } catch (e) { return false; }
}, ms || 8000);

async function main() {
  const server = await serve();
  const browser = await chromium.launch(
    // Set PW_CHROME to a Chromium binary if Playwright's own download is
    // not available; otherwise it finds its own.
    process.env.PW_CHROME ? { executablePath: process.env.PW_CHROME } : {});

  /* Geolocation on, positioned inside site A's fence. Overridden per
     test where a different position is the point. */
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 3,
    permissions: ["geolocation"],
    geolocation: { latitude: SITE_A.latitude, longitude: SITE_A.longitude, accuracy: 8 },
    userAgent: "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36"
  });

  const page = await context.newPage();
  const pageErrors = [];
  page.on("pageerror", e => pageErrors.push(String(e)));
  page.on("console", m => { if (m.type() === "error") pageErrors.push("console: " + m.text()); });

  const backend = makeBackend({
    email: "dave@example.co.uk", password: "correct-horse", me: ME,
    profiles: [OTHER, ME], sites: [SITE_A, SITE_B], work_allocations: [ALLOC],
    tradesman_details: [
      { user_id: OTHER.id, main_trade: "Bricklayer" },
      { user_id: ME.id, main_trade: "Carpenter" }
    ]
  });
  await backend.install(page);

  await page.goto(BASE);

  /* ================= 1. the shell ================= */
  section("1. Static checks");
  const html = fs.readFileSync(path.join(APP_DIR, "index.html"), "utf8");
  const sw = fs.readFileSync(path.join(APP_DIR, "sw.js"), "utf8");
  const manifest = JSON.parse(fs.readFileSync(path.join(APP_DIR, "manifest.webmanifest"), "utf8"));
  // The word appears in a comment saying it must never be here. What
  // matters is that no actual secret does: no sb_secret_ key, and no JWT
  // whose payload claims the service_role.
  const decodedJwtRoles = (html.match(/eyJ[A-Za-z0-9_-]{20,}/g) || []).map(t => {
    try { return Buffer.from(t, "base64").toString("utf8"); } catch (e) { return ""; }
  }).join(" ");
  check("no service_role key anywhere in the app",
    !/sb_secret_/.test(html + sw) && !/service_role/.test(decodedJwtRoles));
  check("publishable key present", html.includes("sb_publishable_"));
  check("manifest is installable (name, icons, start_url, display)",
    !!manifest.name && manifest.icons.length >= 2 && !!manifest.start_url
    && manifest.display === "standalone");
  check("manifest has a maskable icon",
    manifest.icons.some(i => i.purpose === "maskable"));
  check("service worker never caches Supabase",
    /url\.origin\s*!==\s*self\.location\.origin/.test(sw));
  // getCurrentPosition is allowed — that is the one fix per tap. A
  // watcher of any kind is not.
  check("no background location API is used anywhere",
    !/watchPosition|startMonitoring|significantLocation|requestAlways/i.test(html));
  check("location is read exactly one way",
    (html.match(/geolocation\.\w+/g) || []).every(m => m === "geolocation.getCurrentPosition"));
  check("every icon the manifest names exists on disk",
    manifest.icons.every(i => fs.existsSync(path.join(APP_DIR, i.src.replace("./", "")))));

  /* ================= 2. sign in ================= */
  section("2. Sign in");
  await page.fill("#email", "dave@example.co.uk");
  await page.fill("#pass", "wrong");
  await page.click("#signin");
  check("a wrong password is refused with the server's own words",
    await waitFor(async () => (await text(page, "#gatemsg")).includes("Invalid login")));

  await page.fill("#pass", "correct-horse");
  await page.click("#signin");
  check("signing in opens the app",
    await waitFor(async () => await page.isVisible("#v-today")));
  check("the greeting uses his first name",
    (await text(page, "#v-today")).includes("Dave"));
  // The account that runs the office is often on site too, and an Admin
  // can read every profile in the company. Asking for "a profile" would
  // open the app as whoever came back first.
  check("it loads HIS profile by id, not whichever row came back first",
    !(await text(page, "#v-today")).includes("Alan"),
    (await text(page, "#v-today")).split("\n")[0]);
  check("the profile request names his own id",
    backend.calls.some(c => c.path === "/rest/v1/profiles"
      && c.query.includes("id=eq." + ME.id)));
  check("the trade is read for him, not for whoever is first in the table",
    backend.calls.some(c => c.path === "/rest/v1/tradesman_details"
      && c.query.includes("user_id=eq." + ME.id)));
  check("today's allocation is loaded",
    await waitFor(async () =>
      (await page.evaluate(() => window.localStorage.getItem("mysite.crew.cache") || ""))
        .includes("Second fix")));

  /* ================= 3. clock on, inside the fence ================= */
  section("3. Clock on — inside the geofence");
  await page.click("#clockin");
  check("the sheet resolves a fix and reports being on site",
    await waitFor(async () => (await text(page, "#ck-result")).includes("You are on site")));
  check("no reason is demanded when the fix is good",
    !(await page.isVisible("#ck-reasonwrap")));
  await page.click("#ck-go");
  check("the clock is running on Today",
    await waitFor(async () => (await text(page, "#v-today")).includes("Clock out")));

  check("a clock_records row reached the backend",
    await landed(() => backend.db.clock_records.length === 1));
  const clockRow = backend.db.clock_records[0] || {};
  check("its status is the same string the iOS app writes",
    clockRow && clockRow.clock_in_status === "Valid",
    clockRow && clockRow.clock_in_status);
  check("it recorded the distance from the site",
    clockRow && clockRow.clock_in_distance >= 0 && clockRow.clock_in_distance < 30,
    clockRow && String(clockRow.clock_in_distance));
  check("it is marked inside the fence", clockRow && clockRow.clock_in_inside === true);
  const clockPost = backend.calls.find(
    c => c.method === "POST" && c.path === "/rest/v1/clock_records");
  check("the client did not invent a company_id",
    !!clockPost && clockPost.body
    && !Object.prototype.hasOwnProperty.call(clockPost.body, "company_id"));

  /* ================= 4. work lines and the arithmetic ================= */
  section("4. Logging work");
  await page.click("#addline");
  await page.fill("#wl-desc", "First fix to plots 3 and 4");
  await page.selectOption("#wl-min", "150");                       // 2h 30m
  await page.click("#wl-save");
  check("the line appears on Today with the right duration",
    await waitFor(async () => (await text(page, "#v-today")).includes("2h 30m")));

  await page.click("#addline");
  await page.fill("#wl-desc", "Snagging, plot 1");
  await page.selectOption("#wl-cat", "Snagging");
  await page.selectOption("#wl-min", "45");
  await page.selectOption("#wl-site", SITE_B.id);
  await page.click("#wl-save");

  const todayText = await text(page, "#v-today");
  check("two lines are shown and totalled as 3h 15m",
    todayText.includes("2 jobs · 3h 15m"), todayText.split("\n").slice(0, 12).join(" | "));
  check("the totals tile agrees", todayText.includes("3h 15m"));
  // A layout assertion, not just a text one. These are spans inside a
  // span: left inline, the site name runs on from the end of the
  // description and the row reads as one run-on sentence. The text
  // assertions above pass either way, which is the trap.
  check("each line's site and category sit on their own row, not run on",
    await page.$eval(".rows .row", n => {
      const t = n.querySelector(".t"), m = n.querySelector(".m");
      return m.getBoundingClientRect().top >= t.getBoundingClientRect().bottom - 1;
    }));
  check("both lines reached the backend",
    await landed(() => backend.db.work_log_entries.length === 2),
    "rows=" + backend.db.work_log_entries.length);
  check("minutes are stored as integers, not decimal hours",
    backend.db.work_log_entries.every(w => Number.isInteger(w.minutes)));
  check("the second line kept its own site and category",
    backend.db.work_log_entries[1].site_id === SITE_B.id
    && backend.db.work_log_entries[1].category === "Snagging");
  check("no work-line request carried a company_id",
    backend.calls.filter(c => c.method === "POST" && c.path === "/rest/v1/work_log_entries")
      .every(c => !Object.prototype.hasOwnProperty.call(c.body, "company_id")));
  check("work lines are upserted so a retry corrects rather than duplicates",
    backend.calls.filter(c => c.method === "POST" && c.path === "/rest/v1/work_log_entries")
      .every(c => (c.headers.prefer || "").includes("merge-duplicates")));

  /* editing and voiding */
  await page.click("[data-editline]");
  await page.selectOption("#wl-min", "180");
  await page.click("#wl-save");
  check("editing a line corrects it in place, it does not add a second",
    await landed(() => backend.db.work_log_entries.length === 2
      && backend.db.work_log_entries[0].minutes === 180),
    "rows=" + backend.db.work_log_entries.length);
  check("the total moved with it",
    await waitFor(async () => (await text(page, "#v-today")).includes("3h 45m")));

  await page.click("[data-editline]");
  await page.click("#wl-void");
  check("a removed line is voided, never deleted",
    await landed(() => backend.db.work_log_entries.length === 2
      && backend.db.work_log_entries[0].voided === true));
  check("it comes off the total",
    await waitFor(async () => (await text(page, "#v-today")).includes("1 job · 45m")));

  /* ================= 5. clock out and the day sheet ================= */
  section("5. Clock out, and closing the day");
  await page.click("#clockout");
  check("clocking out resolves its own single fix",
    await waitFor(async () => (await text(page, "#ck-result")).length > 0));
  await page.click("#ck-go");
  check("the clock-out was a PATCH of the same row, not a new one",
    await landed(() => backend.db.clock_records.length === 1
      && !!backend.db.clock_records[0].clock_out_time));
  check("clock-out was sent as a patch",
    backend.calls.some(c => c.method === "PATCH" && c.path === "/rest/v1/clock_records"));

  await page.click("#closeday");
  check("a day sheet was written", await landed(() => backend.db.daily_records.length === 1));
  const sheet = backend.db.daily_records[0] || {};
  check("its hours come from the logged lines, not the clock",
    sheet && Math.abs(sheet.total_hours - 0.75) < 0.001, sheet && String(sheet.total_hours));
  check("it is filed against the site most of the day went to",
    sheet && sheet.site_id === SITE_B.id);
  check("the description is built from the lines, not retyped",
    sheet && sheet.description.includes("Snagging, plot 1 (45m)"));
  check("the voided line is not in the description",
    sheet && !sheet.description.includes("First fix"));
  check("start and finish come off the clock",
    sheet && /^\d{2}:\d{2}$/.test(sheet.start_time) && /^\d{2}:\d{2}$/.test(sheet.finish_time),
    sheet && sheet.start_time + "–" + sheet.finish_time);
  check("the trade came from tradesman_details", sheet && sheet.trade === "Carpenter");

  await page.click("#closeday");
  await sleep(800);
  check("closing twice corrects the same sheet rather than making a second",
    backend.db.daily_records.length === 1);

  /* ================= 6. job progress ================= */
  section("6. Job progress");
  await page.click('#tabs [data-tab="jobs"]');
  await page.click('.steps [data-step="50"]');
  await page.fill("#pg-note", "waiting on the plasterboard");
  await page.click("#pg-save");
  check("a progress row was written",
    await landed(() => backend.db.allocation_progress.length === 1
      && backend.db.allocation_progress[0].percent === 50));
  const prog = backend.db.allocation_progress[0] || {};
  check("the note went with it", prog && prog.note === "waiting on the plasterboard");
  check("progress is insert-only, so a retry cannot be refused by RLS",
    backend.calls.filter(c => c.method === "POST" && c.path === "/rest/v1/allocation_progress")
      .every(c => (c.headers.prefer || "").includes("ignore-duplicates")));
  check("the bar on screen moved to 50%",
    await waitFor(async () => (await text(page, "#v-jobs")).includes("50%")));

  /* ================= 7. materials ================= */
  section("7. Material requests");
  await page.click('#tabs [data-tab="mats"]');
  await page.click("#askmat");
  await page.fill(".mt-desc", "12.5mm plasterboard");
  await page.fill(".mt-qty", "12 sheets");
  await page.click("#mt-add");
  const descs = await page.$$(".mt-desc");
  await descs[1].fill("Scrim tape");
  const qtys = await page.$$(".mt-qty");
  await qtys[1].fill("4 rolls");
  await page.click("#mt-send");
  check("both lines were sent as separate requests",
    await landed(() => backend.db.material_requests.length === 2),
    "rows=" + backend.db.material_requests.length);
  check("each carries its own quantity",
    backend.db.material_requests.map(r => r.quantity).sort().join("|") === "12 sheets|4 rolls");
  check("they land as Requested, for the office to move",
    backend.db.material_requests.every(r => r.status === "Requested"));
  check("material requests are insert-only too",
    backend.calls.filter(c => c.method === "POST" && c.path === "/rest/v1/material_requests")
      .every(c => (c.headers.prefer || "").includes("ignore-duplicates")));

  /* ================= 8. photos ================= */
  section("8. Photos");
  await page.click('#tabs [data-tab="today"]');
  await page.click("#addphoto");
  // A real JPEG, 40×30, produced in the page so the file input gets
  // something the canvas can actually decode.
  await page.setInputFiles("#ph-file", {
    name: "site.jpg",
    mimeType: "image/jpeg",
    buffer: Buffer.from(
      "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a"
      + "HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAAeACgBAREA/8QAHwAAAQUBAQEB"
      + "AQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1Fh"
      + "ByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZ"
      + "WmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXG"
      + "x8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/APn+iiiigD//2Q==",
      "base64")
  });
  await page.fill("#ph-desc", "Blockwork up to DPC, plot 3");
  await page.click("#ph-save");
  check("the photo uploaded", await waitFor(() => backend.uploads.length === 1));
  const up = backend.uploads[0];
  const segs = up ? up.path.split("/") : [];
  check("the object path has the three segments the storage policy parses",
    segs.length === 4, up && up.path);
  check("segment 1 is the company, lower case",
    segs[0] === ME.company_id.toLowerCase(), segs[0]);
  // Whichever site the app defaulted to — the site of the last work
  // line, which is site B by this point in the run.
  check("segment 2 is the site the app defaulted to",
    segs[1] === SITE_B.id.toLowerCase(), segs[1]);
  check("segment 3 is the owner", segs[2] === ME.id.toLowerCase());
  check("the whole path is lower case, as the policy compares it",
    up && up.path === up.path.toLowerCase());
  check("a site_photos row followed the upload",
    backend.db.site_photos.length === 1
    && backend.db.site_photos[0].storage_path === up.path);
  check("the photo was shrunk before it was sent (under 300KB)",
    up && up.bytes > 0 && up.bytes < 300000, up && up.bytes + " bytes");
  check("thumbnails are signed in one request, not one per photo",
    backend.calls.filter(c => c.path.startsWith("/storage/v1/object/sign/")).length <= 1);

  /* ================= 9. offline ================= */
  section("9. No signal");
  backend.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await page.click("#addline");
  await page.fill("#wl-desc", "Boarding out the loft");
  await page.selectOption("#wl-min", "120");
  await page.click("#wl-save");
  check("the line still appears on screen with no signal",
    await waitFor(async () => (await text(page, "#v-today")).includes("Boarding out the loft")));
  check("it did not reach the backend", backend.db.work_log_entries.length === 2);
  check("the header says how much is waiting",
    await waitFor(async () => /Offline · \d+ to send/.test(await text(page, "#state"))));
  const queued = await page.evaluate(() => new Promise(res => {
    const r = indexedDB.open("mysite-crew", 1);
    r.onsuccess = () => {
      const q = r.result.transaction("queue", "readonly").objectStore("queue").getAll();
      q.onsuccess = () => res(q.result.length);
    };
  }));
  check("the write is sitting in the queue on the phone", queued >= 1, "queued=" + queued);

  backend.setOffline(false);
  await page.evaluate(() => window.dispatchEvent(new Event("online")));
  check("it flushes when the signal comes back",
    await waitFor(() => backend.db.work_log_entries.length === 3, 8000),
    "rows=" + backend.db.work_log_entries.length);
  check("the header goes quiet once everything is sent",
    await waitFor(async () => !/to send/.test(await text(page, "#state"))));

  /* ================= 10. staying signed in ================= */
  section("10. Staying signed in, and outside the fence");
  await page.reload();
  check("reopening the app does not ask for the password again",
    await waitFor(async () => await page.isVisible("#v-today")));
  check("the day survived the reload",
    (await text(page, "#v-today")).includes("Boarding out the loft"));

  // 2km away — well outside site A's 150m fence.
  await context.setGeolocation({ latitude: 51.5187, longitude: -0.1246, accuracy: 10 });
  await page.click("#clockin");
  await page.waitForSelector("#ck-site");
  await page.selectOption("#ck-site", SITE_A.id);
  check("being off site is reported with the distance",
    await waitFor(async () => /outside its 150m boundary/.test(await text(page, "#ck-result"))),
    (await text(page, "#ck-result")).replace(/\n/g, " ").slice(0, 140));
  check("a reason is now required", await page.isVisible("#ck-reasonwrap"));
  await page.click("#ck-go");
  check("it refuses to record without one",
    await waitFor(async () => (await text(page, "#toast")).includes("reason is needed")));
  await page.fill("#ck-reason", "parked in the overflow car park");
  await page.click("#ck-go");
  check("the entry is still recorded — the clock is evidence, not a gate",
    await landed(() => backend.db.clock_records.length === 2),
    "rows=" + backend.db.clock_records.length);
  const off = backend.db.clock_records[backend.db.clock_records.length - 1] || {};
  check("flagged for review with the iOS app's exact wording",
    off && off.clock_in_status === "Outside Site - Review Required", off && off.clock_in_status);
  check("the reason went with it",
    off && off.reason_note === "parked in the overflow car park");
  check("the distance is recorded, not rounded away",
    off && off.clock_in_distance > 1000, off && String(Math.round(off.clock_in_distance)));

  /* ================= 11. location denied ================= */
  section("11. Location switched off");
  const ctx2 = await browser.newContext({
    viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true,
    permissions: []                                   // denied
  });
  const p2 = await ctx2.newPage();
  const b2 = makeBackend({
    email: "dave@example.co.uk", password: "correct-horse", me: ME,
    profiles: [ME], sites: [SITE_A], work_allocations: [ALLOC], tradesman_details: []
  });
  await b2.install(p2);
  await p2.goto(BASE);
  await p2.fill("#email", "dave@example.co.uk");
  await p2.fill("#pass", "correct-horse");
  await p2.click("#signin");
  await p2.waitForSelector("#v-today");
  await p2.click("#clockin");
  check("a refused location does not hang the sheet",
    await waitFor(async () => (await p2.$eval("#ck-result", n => n.innerText)
      .catch(() => "")).includes("Location is off"), 20000));
  await p2.fill("#ck-reason", "phone location is off");
  await p2.click("#ck-go");
  check("the day is still recorded",
    await landed(() => b2.db.clock_records.length === 1), "no row written");
  const denied = b2.db.clock_records[0] || {};
  check("marked for admin review in the iOS app's words",
    denied && denied.clock_in_status === "Location Permission Denied - Admin Review Required",
    denied && denied.clock_in_status);
  check("no coordinates were invented",
    denied && denied.clock_in_lat === null && denied.clock_in_lng === null);
  await ctx2.close();

  /* ================= 12. a user with no company ================= */
  section("12. Signed in, but not attached to a company");
  const ctx3 = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const p3 = await ctx3.newPage();
  const orphan = Object.assign({}, ME, { company_id: null });
  const JOIN_CO = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
  const later = new Date(Date.now() + 7 * 864e5).toISOString();
  const b3 = makeBackend({
    email: "new@example.co.uk", password: "pw", me: orphan,
    profiles: [orphan], sites: [SITE_A], work_allocations: [], tradesman_details: [],
    invites: [
      { code: "MPG-USED-CODE", role: "Tradesman", company_id: JOIN_CO,
        used_by: OTHER.id, expires_at: later, revoked: false },
      { code: "MPG-AB3D-7KQ2", role: "Tradesman", company_id: JOIN_CO,
        used_by: null, expires_at: later, revoked: false }
    ]
  });
  await b3.install(p3);
  await p3.goto(BASE);
  await p3.fill("#email", "new@example.co.uk");
  await p3.fill("#pass", "pw");
  await p3.click("#signin");
  check("he gets a setup screen, not eight empty lists",
    await waitFor(async () => await p3.isVisible("#setup")));
  check("and is told what to do about it",
    (await p3.$eval("#setup", n => n.innerText)).includes("not attached to a company"));
  const setupMsg = () => p3.$eval("#setupmsg", n => n.innerText).catch(() => "");

  await p3.click("#setupretry");
  check("Check again, before the office has done anything, says so and stays put",
    await waitFor(async () => (await setupMsg()).includes("Not added yet"))
    && await p3.isVisible("#setup"));

  check("there is somewhere to type an invite code", await p3.isVisible("#invite"));
  await p3.click("#redeem");
  check("an empty code is caught on the phone, not sent",
    (await setupMsg()).includes("Put the code in first")
    && !b3.calls.some(c => c.path === "/rest/v1/rpc/redeem_role_invite"));

  await p3.fill("#invite", "MPG-ZZZZ-ZZZZ");
  await p3.click("#redeem");
  check("an unknown code is refused in the server's own words",
    await waitFor(async () => (await setupMsg()).includes("not recognised")),
    await setupMsg());
  await p3.fill("#invite", "mpg-used-code");
  await p3.press("#invite", "Enter");
  check("a used code is refused in the server's own words (and Enter submits)",
    await waitFor(async () => (await setupMsg()).includes("already been used")),
    await setupMsg());
  check("a refused code leaves him on the setup screen",
    await p3.isVisible("#setup") && !(await p3.isVisible("#app")));

  // Read out over the phone and typed with thumbs: lower case, a space,
  // no prefix. It should still be the right code.
  await p3.fill("#invite", "  ab3d 7kq2 ");
  await p3.click("#redeem");
  check("a good code opens the app",
    await waitFor(async () => await p3.isVisible("#v-today"), 8000));
  const rpc = b3.calls.filter(c => c.path === "/rest/v1/rpc/redeem_role_invite").pop() || {};
  check("a sloppily typed code is tidied to MPG-XXXX-XXXX before it is sent",
    rpc.body && rpc.body.p_code === "MPG-AB3D-7KQ2", rpc.body && rpc.body.p_code);
  check("the redeem call carries only the code — no company_id, no role",
    rpc.body && Object.keys(rpc.body).join(",") === "p_code", rpc.body && Object.keys(rpc.body).join(","));
  check("it went with his signed-in token, not the bare publishable key",
    /^Bearer tok-/.test((rpc.headers || {}).authorization || ""));
  const rpcAt = b3.calls.indexOf(rpc);
  check("his own profile is re-read after redeeming, so the company comes from the server",
    b3.calls.slice(rpcAt + 1).some(c => c.method === "GET" && c.path === "/rest/v1/profiles"
      && c.query.includes("id=eq." + orphan.id)));
  check("the server now has him in the inviting company",
    b3.db.profiles[0].company_id === JOIN_CO && b3.db.profiles[0].role === "Tradesman");
  check("the code is spent", !!b3.invites[1].used_by);
  check("he is welcomed in",
    await waitFor(async () => (await p3.$eval("#toast", n => n.innerText).catch(() => ""))
      .includes("You're in")));
  check("the setup screen is gone", !(await p3.isVisible("#setup")));
  await p3.reload();
  check("and stays gone after the app is reopened",
    await waitFor(async () => await p3.isVisible("#v-today"))
    && !(await p3.isVisible("#setup")));
  await ctx3.close();

  /* A code with no signal gets told why, not a raw browser error. */
  const ctx4 = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const p4 = await ctx4.newPage();
  const orphan2 = Object.assign({}, ME, { company_id: null });
  const b4 = makeBackend({ email: "new@example.co.uk", password: "pw", me: orphan2,
    profiles: [orphan2], sites: [], work_allocations: [], tradesman_details: [] });
  await b4.install(p4);
  await p4.goto(BASE);
  await p4.fill("#email", "new@example.co.uk");
  await p4.fill("#pass", "pw");
  await p4.click("#signin");
  await p4.waitForSelector("#setup:not([hidden])");
  b4.setOffline(true);
  await p4.fill("#invite", "MPG-AB3D-7KQ2");
  await p4.click("#redeem");
  check("using a code with no signal says so plainly",
    await waitFor(async () => (await p4.$eval("#setupmsg", n => n.innerText))
      .includes("No signal")), await p4.$eval("#setupmsg", n => n.innerText));
  await ctx4.close();

  /* ================= 13. session refresh ================= */
  section("13. An expired token");
  const before = backend.refreshCount;
  // The server decides a token is stale, which is how this actually
  // happens — not by the phone noticing first.
  backend.expireTokens(1);
  await page.click('#tabs [data-tab="me"]');
  await page.click("#refresh");
  check("a 401 makes the app refresh its own token rather than signing him out",
    await waitFor(() => backend.refreshCount > before, 9000),
    "refreshes " + before + " → " + backend.refreshCount);
  check("and the request is retried, so he never sees the failure",
    await waitFor(async () => (await text(page, "#toast")).includes("Up to date"), 9000),
    await text(page, "#toast"));
  check("he is still signed in", await page.isVisible("#app"));

  /* ================= 14. nothing threw ================= */
  section("14. Console");
  // Three of these are the point of the tests that caused them: the 400
  // is the wrong password, the 401 is the expired token, and the
  // disconnection is the offline run. Anything else is a real fault.
  const realErrors = pageErrors.filter(e =>
    !/status of 400|status of 401|status of 403|ERR_INTERNET_DISCONNECTED|net::ERR_FAILED/.test(e));
  check("no uncaught errors anywhere in the run",
    realErrors.length === 0, realErrors.slice(0, 3).join(" ¦ "));

  await browser.close();
  server.close();

  console.log("\n" + "=".repeat(58));
  console.log(passed + " passed, " + failures.length + " failed");
  if (failures.length) {
    console.log("\nFailures:");
    failures.forEach(f => console.log("  · " + f));
    process.exit(1);
  }
  console.log("All green.");
}

main().catch(e => { console.error(e); process.exit(1); });
