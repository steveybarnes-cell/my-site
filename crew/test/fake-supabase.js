/* A stand-in for the real backend, faithful to the parts the crew app
   touches: GoTrue's password grant and refresh, PostgREST selects and
   upserts with Prefer resolution, PATCH by id, and the Storage upload
   and batch-sign endpoints.

   It also records every request so the tests can assert on what the app
   actually sent — which is the point. Testing that a screen renders
   proves nothing about the row that reaches the database. */

"use strict";

const SUPA = "https://jzzsatsmdmckgjllohst.supabase.co";

function makeBackend(seed) {
  const db = {
    profiles: seed.profiles || [],
    sites: seed.sites || [],
    work_allocations: seed.work_allocations || [],
    work_log_entries: [],
    clock_records: [],
    site_photos: [],
    material_requests: [],
    allocation_progress: [],
    daily_records: [],
    tradesman_details: seed.tradesman_details || []
  };

  const calls = [];          // every request the app made
  const uploads = [];        // storage uploads
  let refreshCount = 0;
  let failNetwork = false;   // flip to simulate no signal
  let expireNext = 0;        // reply 401 to the next N PostgREST calls

  const me = seed.me;
  const invites = seed.invites || [];   // role_invites rows

  function parseQuery(qs) {
    const out = {};
    new URLSearchParams(qs).forEach((v, k) => { out[k] = v; });
    return out;
  }

  /** The subset of PostgREST filters the app uses. */
  function applyFilters(rows, q) {
    let out = rows.slice();
    Object.keys(q).forEach(k => {
      if (["select", "order", "limit", "offset"].includes(k)) return;
      const v = q[k];
      const m = /^(eq|gte|lte|gt|lt|is)\.(.*)$/.exec(v);
      if (!m) return;
      const [, op, raw] = m;
      out = out.filter(r => {
        const cell = r[k];
        if (op === "eq") return String(cell) === raw;
        if (op === "gte") return String(cell) >= raw;
        if (op === "lte") return String(cell) <= raw;
        if (op === "gt") return String(cell) > raw;
        if (op === "lt") return String(cell) < raw;
        if (op === "is") return raw === "false" ? cell === false
          : raw === "true" ? cell === true : cell == null;
        return true;
      });
    });
    if (q.limit) out = out.slice(0, Number(q.limit));
    return out;
  }

  async function handle(route, request) {
    const url = new URL(request.url());
    const method = request.method();
    let body = null;
    try { body = request.postDataJSON(); } catch (e) { body = request.postData(); }

    calls.push({
      method,
      path: url.pathname,
      query: url.search,
      headers: request.headers(),
      body
    });

    if (failNetwork) { await route.abort("internetdisconnected"); return; }

    const json = (status, data, headers) => route.fulfill({
      status,
      contentType: "application/json",
      headers: Object.assign({ "access-control-allow-origin": "*" }, headers || {}),
      body: JSON.stringify(data === undefined ? null : data)
    });

    if (method === "OPTIONS") {
      await route.fulfill({
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "*",
          "access-control-allow-methods": "*"
        },
        body: ""
      });
      return;
    }

    /* ---------------- GoTrue ---------------- */
    if (url.pathname === "/auth/v1/token") {
      const grant = url.searchParams.get("grant_type");
      if (grant === "password") {
        if (body && body.email === seed.email && body.password === seed.password) {
          await json(200, {
            access_token: "tok-1", refresh_token: "ref-1", expires_in: 3600,
            user: { id: me.id, email: me.email }
          });
        } else {
          await json(400, { error_description: "Invalid login credentials" });
        }
        return;
      }
      if (grant === "refresh_token") {
        refreshCount++;
        await json(200, {
          access_token: "tok-" + (refreshCount + 1), refresh_token: "ref-1",
          expires_in: 3600, user: { id: me.id, email: me.email }
        });
        return;
      }
    }
    if (url.pathname === "/auth/v1/recover") { await json(200, {}); return; }

    /* ---------------- Storage ---------------- */
    if (url.pathname.startsWith("/storage/v1/object/sign/")) {
      const paths = (body && body.paths) || [];
      await json(200, paths.map(p => ({
        path: p, signedURL: "/object/sign/site-evidence/" + p + "?token=fake"
      })));
      return;
    }
    if (url.pathname.startsWith("/storage/v1/object/") && method === "POST") {
      const key = url.pathname.replace("/storage/v1/object/site-evidence/", "");
      uploads.push({ path: key, bytes: (request.postDataBuffer() || { length: 0 }).length });
      await json(200, { Key: "site-evidence/" + key });
      return;
    }

    /* ---------------- PostgREST RPC ---------------- */
    // redeem_role_invite as 0005 defines it: upper(trim()) the code, refuse
    // unknown / revoked / used / expired, refuse a man already in a
    // different company, then set role AND company_id together. Errors
    // come back the way PostgREST sends a RAISE: the message in the body,
    // 400 for 22023 and 403 for 42501.
    if (url.pathname === "/rest/v1/rpc/redeem_role_invite" && method === "POST") {
      const code = String((body && body.p_code) || "").trim().toUpperCase();
      const inv = invites.find(i => i.code === code);
      const refuse = (status, errcode, message) =>
        json(status, { code: errcode, details: null, hint: null, message });
      if (!inv) return refuse(400, "22023", "That invite code was not recognised.");
      if (inv.revoked) return refuse(400, "22023", "That invite has been revoked.");
      if (inv.used_by) return refuse(400, "22023", "That invite has already been used.");
      if (inv.expires_at && new Date(inv.expires_at) < new Date())
        return refuse(400, "22023", "That invite has expired.");
      const row = db.profiles.find(r => r.id === me.id);
      if (row && row.company_id && row.company_id !== inv.company_id)
        return refuse(403, "42501", "That invite belongs to a different company.");
      if (row) { row.role = inv.role; row.company_id = inv.company_id; }
      me.company_id = inv.company_id;   // so later inserts default to it, as the server would
      inv.used_by = me.id; inv.used_at = new Date().toISOString();
      await json(200, inv.role);
      return;
    }

    /* ---------------- PostgREST ---------------- */
    if (url.pathname.startsWith("/rest/v1/")) {
      if (expireNext > 0) {
        expireNext--;
        await json(401, { message: "JWT expired" });
        return;
      }
      const table = url.pathname.replace("/rest/v1/", "");
      if (!(table in db)) { await json(404, { message: "no such table " + table }); return; }
      const q = parseQuery(url.search.replace(/^\?/, ""));

      if (method === "GET") {
        // profiles is seeded the way an Admin's RLS would return it —
        // every profile in the company, not just his own — so an app
        // that asks for `limit=1` and hopes gets caught here.
        await json(200, applyFilters(db[table], q));
        return;
      }

      if (method === "POST") {
        const prefer = request.headers()["prefer"] || "";
        const rows = Array.isArray(body) ? body : [body];
        for (const row of rows) {
          const i = db[table].findIndex(r => r.id === row.id);
          if (i >= 0) {
            if (prefer.includes("ignore-duplicates")) continue;   // ON CONFLICT DO NOTHING
            db[table][i] = Object.assign({}, db[table][i], row);
          } else {
            // company_id is the server's business, not the client's.
            db[table].push(Object.assign({ company_id: me.company_id }, row));
          }
        }
        await json(201, prefer.includes("return=minimal") ? null : rows);
        return;
      }

      if (method === "PATCH") {
        const q2 = parseQuery(url.search.replace(/^\?/, ""));
        const id = (q2.id || "").replace(/^eq\./, "");
        const i = db[table].findIndex(r => r.id === id);
        if (i >= 0) db[table][i] = Object.assign({}, db[table][i], body);
        await json(200, null);
        return;
      }
    }

    await json(404, { message: "unhandled " + method + " " + url.pathname });
  }

  return {
    db, calls, uploads, invites,
    get refreshCount() { return refreshCount; },
    setOffline(v) { failNetwork = !!v; },
    expireTokens(n) { expireNext = n; },
    install: page => page.route(SUPA + "/**", (route, request) => handle(route, request))
  };
}

module.exports = { makeBackend, SUPA };
