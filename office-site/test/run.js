/* =====================================================================
   Headless checks of the office portal's joining card: who is waiting,
   Approve with a role, Decline, the company code, and that the People
   list only ever shows this company's people.

   Like the crew tests, every write is checked at the request that left
   the page, not just on screen.
   ===================================================================== */
"use strict";

const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const APP_DIR = path.resolve(__dirname, "..");
const PORT = 8791;
const BASE = "http://localhost:" + PORT + "/";
const SUPA = "https://jzzsatsmdmckgjllohst.supabase.co";

function serve() {
  return new Promise(resolve => {
    const s = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split("?")[0]);
      if (p === "/") p = "/index.html";
      const f = path.join(APP_DIR, p);
      if (!f.startsWith(APP_DIR) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(fs.readFileSync(f));
    });
    s.listen(PORT, () => resolve(s));
  });
}

const CO = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const ADMIN = { id: "11111111-1111-4111-8111-111111111111", company_id: CO, name: "Steve Barnes",
  email: "steve@example.co.uk", role: "Admin" };
const DAVE = { id: "22222222-2222-4222-8222-222222222222", company_id: CO, name: "Dave Sturrock",
  email: "dave@example.co.uk", role: "Tradesman" };
// Has asked to join: an admin's RLS returns his profile row (company null).
const DAN = { id: "33333333-3333-4333-8333-333333333333", company_id: null, name: "Dan Newman",
  email: "dan@new.example", role: "Tradesman" };
const ED = { id: "44444444-4444-4444-8444-444444444444", company_id: null, name: "Ed Other",
  email: "ed@new.example", role: "Tradesman" };

function makeBackend(opts) {
  const o = opts || {};
  const me = o.me || ADMIN;
  const profiles = [ADMIN, DAVE, DAN, ED].map(p => Object.assign({}, p));
  let code = "K7M4QX";
  const joins = o.noJoins ? [] : [
    { id: "jr-1", user_id: DAN.id, name: DAN.name, email: DAN.email,
      created_at: new Date(Date.now() - 3 * 3600e3).toISOString() },
    { id: "jr-2", user_id: ED.id, name: ED.name, email: ED.email,
      created_at: new Date(Date.now() - 20 * 60e3).toISOString() }
  ];
  const calls = [];
  const tables = { sites: [], clock_records: [], work_log_entries: [], daily_records: [],
    weekly_submissions: [], materials: [], site_photos: [], tradesman_details: [],
    companies: [{ id: CO, name: "Smith Building", hubdoc_email: "x@hubdoc.com" }] };

  async function handle(route, req) {
    const url = new URL(req.url()); const method = req.method();
    let body = null; try { body = req.postDataJSON(); } catch (e) {}
    calls.push({ method, path: url.pathname, query: url.search, body });
    const json = (status, data) => route.fulfill({ status, contentType: "application/json",
      headers: { "access-control-allow-origin": "*" }, body: JSON.stringify(data === undefined ? null : data) });
    if (method === "OPTIONS") return route.fulfill({ status: 204, headers: {
      "access-control-allow-origin": "*", "access-control-allow-headers": "*", "access-control-allow-methods": "*" }, body: "" });

    if (url.pathname === "/auth/v1/token")
      return json(200, { access_token: "tok", refresh_token: "r", expires_in: 3600, user: { id: me.id, email: me.email } });

    const rpcName = (url.pathname.match(/^\/rest\/v1\/rpc\/(\w+)$/) || [])[1];
    if (rpcName) {
      const admin = me.role === "Admin";
      const refuse = (s, m) => json(s, { code: "42501", message: m });
      if (o.noMigration && /join/.test(rpcName))
        return json(404, { code: "PGRST202", message: "Could not find the function public." + rpcName + " in the schema cache" });
      if (rpcName === "pending_join_requests") return admin ? json(200, joins) : refuse(403, "Only an admin can see who is waiting to join.");
      if (rpcName === "company_join_code") return admin ? json(200, code) : refuse(403, "Only an admin can see the company code.");
      if (rpcName === "reset_join_code") { code = "PQ4RTX"; return json(200, code); }
      if (rpcName === "decide_join_request") {
        const i = joins.findIndex(j => j.id === body.p_id);
        if (i < 0) return json(400, { code: "22023", message: "That request was not found." });
        const j = joins.splice(i, 1)[0];
        if (body.p_approve) Object.assign(profiles.find(p => p.id === j.user_id),
          { company_id: CO, role: body.p_role || "Tradesman" });
        return json(200, null);
      }
      if (rpcName === "set_user_role") {
        profiles.find(p => p.id === body.p_user).role = body.p_role; return json(200, null);
      }
      return json(404, { message: "unhandled rpc " + rpcName });
    }

    const table = url.pathname.replace("/rest/v1/", "");
    if (table === "profiles") {
      const idm = /id=eq\.([0-9a-f-]+)/.exec(url.search);
      let rows = profiles;
      if (idm) rows = rows.filter(p => p.id === idm[1]);
      // What 0013's policy gives an admin: his company, plus unattached
      // people who have a pending request to it.
      else rows = rows.filter(p => p.company_id === CO
        || (p.company_id === null && joins.some(j => j.user_id === p.id)));
      return json(200, rows);
    }
    if (table in tables) return json(200, tables[table]);
    return json(404, { message: "unhandled " + url.pathname });
  }
  return { calls, profiles, joins, get code() { return code; },
    install: page => page.route(SUPA + "/**", (r, q) => handle(r, q)) };
}

let passed = 0; const failures = [];
function check(name, ok, detail) {
  if (ok) { passed++; console.log("  ok   " + name); }
  else { failures.push(name); console.log("  FAIL " + name + (detail ? "  →  " + detail : "")); }
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function waitFor(fn, ms) {
  const until = Date.now() + (ms || 5000);
  for (;;) { try { if (await fn()) return true; } catch (e) {} if (Date.now() > until) return false; await sleep(60); }
}

async function signedIn(browser, opts) {
  const ctx = await browser.newContext({ viewport: { width: 1200, height: 900 } });
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", e => errors.push(String(e)));
  const b = makeBackend(opts);
  await b.install(page);
  await page.goto(BASE);
  await page.fill("#email", ((opts && opts.me) || ADMIN).email);
  await page.fill("#pw", "pw");
  await page.click("#signin");
  await page.waitForSelector("#gate.hide", { state: "attached" });
  await sleep(300);
  return { ctx, page, b, errors, text: sel => page.$eval(sel, n => n.innerText).catch(() => "") };
}

async function main() {
  const server = await serve();
  const browser = await chromium.launch(process.env.PW_CHROME ? { executablePath: process.env.PW_CHROME } : {});

  console.log("\n1. An admin with two people waiting");
  const A = await signedIn(browser);
  check("the Today page says people are waiting", (await A.text("#joinNudge")).includes("2 people are waiting"));
  check("the People tab carries a count", (await A.text("#joinBadge")) === "2");
  await A.page.click('#nav button[data-p="people"]');
  const box = await A.text("#joinBox");
  check("both are listed with name and email", box.includes("Dan Newman") && box.includes("ed@new.example"));
  check("how long they've waited is shown", /hours ago|min ago/.test(box));
  check("the company code is shown to the admin", (await A.text("#joinCode")) === "K7M4QX");
  const people = await A.text("#peopleTable");
  check("the People list shows only his own company", people.includes("Dave Sturrock") && people.includes("Steve Barnes"));
  check("…not the people still waiting", !people.includes("Dan Newman") && !people.includes("Ed Other"));

  await A.page.selectOption("#jr-role-jr-1", "Site Manager");
  await A.page.click('[data-approve="jr-1"]');
  check("approving says who and as what",
    await waitFor(async () => (await A.text("#banner")).includes("Dan Newman can now sign in as Site Manager")));
  const ap = A.b.calls.filter(c => c.path === "/rest/v1/rpc/decide_join_request").pop() || {};
  check("the approve call names the request, yes, and the chosen role — nothing else",
    ap.body && ap.body.p_id === "jr-1" && ap.body.p_approve === true && ap.body.p_role === "Site Manager"
    && Object.keys(ap.body).length === 3, JSON.stringify(ap.body));
  check("he moves from waiting into the People list",
    await waitFor(async () => (await A.text("#peopleTable")).includes("Dan Newman")
      && !(await A.text("#joinBox")).includes("Dan Newman")));
  check("the count drops to 1", (await A.text("#joinBadge")) === "1");

  await A.page.click('[data-decline="jr-2"]');
  check("Decline needs a second tap — the first only arms it",
    (await A.text('[data-decline="jr-2"]')).includes("Sure?")
    && !A.b.calls.some(c => c.path === "/rest/v1/rpc/decide_join_request" && c.body.p_id === "jr-2"));
  await A.page.click('[data-decline="jr-2"]');
  check("the second tap declines",
    await waitFor(async () => (await A.text("#banner")).includes("request was declined")));
  const dc = A.b.calls.filter(c => c.path === "/rest/v1/rpc/decide_join_request").pop() || {};
  check("the decline call is a plain no", dc.body && dc.body.p_id === "jr-2" && dc.body.p_approve === false);
  check("a declined man never appears in People",
    !(await A.text("#peopleTable")).includes("Ed Other"));
  check("nobody is waiting now; badge and nudge are gone",
    await waitFor(async () => (await A.text("#joinBox")).includes("Nobody is waiting")
      && !(await A.page.isVisible("#joinBadge")) && (await A.text("#joinNudge")) === ""));

  await A.page.click("#resetCode");
  check("changing the code needs a second tap", !A.b.calls.some(c => c.path === "/rest/v1/rpc/reset_join_code"));
  await A.page.click("#resetCode");
  check("the new code is shown", await waitFor(async () => (await A.text("#joinCode")) === "PQ4RTX"));

  // Role change goes through the audited function, not a PATCH.
  await A.page.selectOption('#peopleTable select', { index: 1 }).catch(() => {});
  await waitFor(() => A.b.calls.some(c => c.path === "/rest/v1/rpc/set_user_role"), 3000);
  check("changing a role uses set_user_role, so a refusal is a real error",
    A.b.calls.some(c => c.path === "/rest/v1/rpc/set_user_role")
    && !A.b.calls.some(c => c.method === "PATCH" && c.path === "/rest/v1/profiles"));
  check("no errors on the page", A.errors.length === 0, A.errors.join(" | "));
  await A.ctx.close();

  console.log("\n2. A site manager");
  const M = await signedIn(browser, { me: Object.assign({}, DAVE, { role: "Site Manager" }) });
  check("does not get the joining card or the code", (await M.text("#joinBox")) === "");
  check("does not even ask for the queue", !M.b.calls.some(c => /join/.test(c.path)));
  await M.ctx.close();

  console.log("\n3. Before migration 0013 is run");
  const O = await signedIn(browser, { noMigration: true });
  await O.page.click('#nav button[data-p="people"]');
  check("the card says what to do instead of breaking the page",
    (await O.text("#joinBox")).includes("run migration 0013")
    && (await O.text("#peopleTable")).includes("Dave Sturrock"));
  check("no errors on the page", O.errors.length === 0, O.errors.join(" | "));
  await O.ctx.close();

  await browser.close(); server.close();
  console.log("\n" + passed + " passed, " + failures.length + " failed");
  if (failures.length) process.exit(1);
}
main().catch(e => { console.error(e); process.exit(1); });
