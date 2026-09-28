/* Screenshots of the real screens, driven through the same fake backend
   as the test run — so what is in the pictures is what the app does, not
   a mock-up. */

"use strict";

const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");
const { makeBackend } = require("./fake-supabase");

const APP_DIR = path.resolve(__dirname, "..");
const OUT = path.resolve(__dirname, "../../shots");
const PORT = 8790;
const BASE = "http://localhost:" + PORT + "/";

const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript",
  ".webmanifest": "application/manifest+json", ".png": "image/png" };

function serve() {
  return new Promise(resolve => {
    const s = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split("?")[0]);
      if (p === "/") p = "/index.html";
      const f = path.join(APP_DIR, p);
      if (!f.startsWith(APP_DIR) || !fs.existsSync(f)) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { "Content-Type": MIME[path.extname(f)] || "application/octet-stream" });
      res.end(fs.readFileSync(f));
    });
    s.listen(PORT, () => resolve(s));
  });
}

const ME = {
  id: "11111111-1111-4111-8111-111111111111",
  company_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  name: "Dave Sturrock", email: "dave@example.co.uk", role: "Tradesman", active: true
};
const SITE = {
  id: "22222222-2222-4222-8222-222222222222", name: "Marlborough Road",
  address: "12 Marlborough Rd", status: "Active",
  latitude: 51.5007, longitude: -0.1246, geofence_radius: 150
};
const SITE2 = {
  id: "33333333-3333-4333-8333-333333333333", name: "Clifton Gardens",
  status: "Active", latitude: 51.48, longitude: -0.1, geofence_radius: 120
};
function iso(d) { const p = n => String(n).padStart(2, "0");
  return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()); }
const T = iso(new Date());
const TOM = iso(new Date(Date.now() + 864e5));

const allocs = [
  { id: "44444444-4444-4444-8444-444444444444", site_id: SITE.id, tradesman_id: ME.id,
    date: T, task_description: "Second fix, plots 3 and 4", trade: "Carpenter",
    category: "Contract Work", status: "In Progress", percent_complete: 50,
    progress_note: "waiting on the plasterboard", notes: "Skip arrives Thursday",
    start_time: "08:00" },
  { id: "55555555-5555-4555-8555-555555555555", site_id: SITE2.id, tradesman_id: ME.id,
    date: TOM, task_description: "Board out the loft", trade: "Carpenter",
    category: "Contract Work", status: "Allocated", percent_complete: 0,
    progress_note: "", notes: "", start_time: "07:30" }
];

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const server = await serve();
  const browser = await chromium.launch(
    process.env.PW_CHROME ? { executablePath: process.env.PW_CHROME } : {});
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
    isMobile: true, hasTouch: true, permissions: ["geolocation"],
    geolocation: { latitude: SITE.latitude, longitude: SITE.longitude, accuracy: 6 }
  });
  const page = await ctx.newPage();
  const backend = makeBackend({
    email: "dave@example.co.uk", password: "pw", me: ME,
    profiles: [ME], sites: [SITE, SITE2], work_allocations: allocs,
    tradesman_details: [{ user_id: ME.id, main_trade: "Carpenter" }]
  });
  await backend.install(page);

  const shot = async name => {
    await sleep(320);
    await page.screenshot({ path: path.join(OUT, name + ".png") });
    console.log("  " + name + ".png");
  };

  await page.goto(BASE);
  await sleep(500);
  await shot("1-signin");

  await page.fill("#email", "dave@example.co.uk");
  await page.fill("#pass", "pw");
  await page.click("#signin");
  await page.waitForSelector("#v-today");
  await sleep(600);

  // Clock on and log a realistic day so the screens have something in them.
  await page.click("#clockin");
  await page.waitForSelector("#ck-result");
  await sleep(900);
  await shot("2-clock-on");
  await page.click("#ck-go");
  await sleep(500);

  await page.click("#addline");
  await page.fill("#wl-desc", "Second fix to plots 3 and 4");
  await page.selectOption("#wl-min", "270");
  await sleep(200);
  await shot("3-add-a-job");
  await page.click("#wl-save");
  await sleep(400);

  await page.click("#addline");
  await page.fill("#wl-desc", "Snagging, plot 1 — door linings");
  await page.selectOption("#wl-cat", "Snagging");
  await page.selectOption("#wl-min", "75");
  await page.click("#wl-save");
  await sleep(700);
  await shot("4-today");

  await page.evaluate(() => window.scrollTo(0, 10000));
  await sleep(400);
  await shot("5-today-total");

  await page.click('#tabs [data-tab="jobs"]');
  await sleep(500);
  await shot("6-jobs");

  await page.click('.steps [data-step="75"]');
  await page.waitForSelector("#pg-note");
  await page.fill("#pg-note", "linings done, waiting on architrave");
  await sleep(250);
  await shot("7-progress");
  await page.click("#pg-save");
  await sleep(400);

  await page.click('#tabs [data-tab="mats"]');
  await page.click("#askmat");
  await page.waitForSelector(".mt-desc");
  await page.fill(".mt-desc", "12.5mm plasterboard");
  await page.fill(".mt-qty", "12 sheets");
  await sleep(250);
  await shot("8-materials-form");
  await page.click("#mt-send");
  await sleep(700);
  await shot("9-materials");

  await page.click('#tabs [data-tab="me"]');
  await sleep(500);
  await shot("10-me");

  // What it looks like with no signal and work waiting.
  backend.setOffline(true);
  await page.evaluate(() => window.dispatchEvent(new Event("offline")));
  await page.click('#tabs [data-tab="today"]');
  await page.click("#addline");
  await page.fill("#wl-desc", "Boarding out the loft");
  await page.selectOption("#wl-min", "120");
  await page.click("#wl-save");
  await sleep(700);
  await shot("11-offline");

  // A new man, signed in but not yet in a company: the invite-code screen.
  const ctx2 = await browser.newContext({ viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const p2 = await ctx2.newPage();
  const newMan = Object.assign({}, ME, { company_id: null, name: "Sam Newman" });
  const b2 = makeBackend({ email: "sam@example.co.uk", password: "pw", me: newMan,
    profiles: [newMan], sites: [], work_allocations: [], tradesman_details: [] });
  await b2.install(p2);
  await p2.goto(BASE);
  await p2.fill("#email", "sam@example.co.uk");
  await p2.fill("#pass", "pw");
  await p2.click("#signin");
  await p2.waitForSelector("#setup:not([hidden])");
  await p2.fill("#invite", "MPG-ZZZZ-ZZZZ");
  await p2.click("#redeem");
  await sleep(700);
  await sleep(320);
  await p2.screenshot({ path: path.join(OUT, "12-invite-code.png") });
  console.log("  12-invite-code.png");
  await ctx2.close();

  // Signing up and waiting to be let in.
  const ctx3 = await browser.newContext({ viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const p3 = await ctx3.newPage();
  const FIRM = { id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", name: "Smith Building", join_code: "K7M4QX" };
  const b3 = makeBackend({ email: "x@x", password: "x", me: { id: "99999999-9999-4999-8999-999999999999" },
    profiles: [], sites: [], work_allocations: [], tradesman_details: [], companies: [FIRM] });
  await b3.install(p3);
  await p3.goto(BASE);
  const snap = async name => { await sleep(350); await p3.screenshot({ path: path.join(OUT, name + ".png") }); console.log("  " + name + ".png"); };
  await snap("13-signin-with-signup");
  await p3.click("#tosignup");
  await p3.fill("#su-name", "Dan Newman"); await p3.fill("#su-email", "dan@new.example");
  await p3.fill("#su-pass", "a-good-long-one");
  await snap("14-create-account");
  await p3.click("#su-go");
  await p3.waitForSelector("#setup:not([hidden])");
  await p3.fill("#invite", "K7M4QX");
  await snap("15-company-code");
  await p3.click("#redeem");
  await p3.waitForFunction(() => document.getElementById("setuph").innerText.includes("Waiting"));
  await snap("16-waiting");
  b3.decide(false);
  await p3.click("#setupretry");
  await p3.waitForFunction(() => document.getElementById("setuph").innerText.includes("Not let in"));
  await snap("17-declined");
  await ctx3.close();

  await browser.close();
  server.close();
  console.log("\nScreenshots in " + OUT);
}

main().catch(e => { console.error(e); process.exit(1); });
