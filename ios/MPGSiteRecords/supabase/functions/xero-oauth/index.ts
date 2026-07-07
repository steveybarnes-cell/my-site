// Xero OAuth 2.0 Edge Function for MPG Site Records.
//
// Routes (path after the function name):
//   GET  /xero-oauth/start     -> returns { url } to open Xero consent (verify_jwt on)
//   GET  /xero-oauth/callback  -> Xero redirects here with ?code&state; exchanges + stores tokens,
//                                 then 302 redirects into the app via mpgsiterecords://xero-connected
//   POST /xero-oauth/refresh   -> refreshes the stored access token, returns { expires_at }
//
// Secrets (Backend): XERO_CLIENT_ID, XERO_CLIENT_SECRET, XERO_REDIRECT_URI
// Uses SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (auto-injected) for token storage.

import { createClient } from "jsr:@supabase/supabase-js@2";

const XERO_AUTH = "https://login.xero.com/identity/connect/authorize";
const XERO_TOKEN = "https://identity.xero.com/connect/token";
const XERO_CONNECTIONS = "https://api.xero.com/connections";
const SCOPES = "openid profile email accounting.transactions accounting.contacts offline_access";
const APP_DEEP_LINK = "mpgsiterecords://xero-connected";
const COMPANY_KEY = "mpg";

const clientId = Deno.env.get("XERO_CLIENT_ID") ?? "";
const clientSecret = Deno.env.get("XERO_CLIENT_SECRET") ?? "";
const redirectUri = Deno.env.get("XERO_REDIRECT_URI") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function admin() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function basicAuthHeader() {
  return "Basic " + btoa(`${clientId}:${clientSecret}`);
}

function notConfigured() {
  return !clientId || !clientSecret || !redirectUri;
}

async function exchangeCode(code: string) {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
  });
  const res = await fetch(XERO_TOKEN, {
    method: "POST",
    headers: {
      Authorization: basicAuthHeader(),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (!res.ok) throw new Error(`token exchange failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

async function refreshToken(refresh_token: string) {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token,
  });
  const res = await fetch(XERO_TOKEN, {
    method: "POST",
    headers: {
      Authorization: basicAuthHeader(),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (!res.ok) throw new Error(`refresh failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

async function fetchTenant(access_token: string) {
  const res = await fetch(XERO_CONNECTIONS, {
    headers: { Authorization: `Bearer ${access_token}`, Accept: "application/json" },
  });
  if (!res.ok) return { tenantId: null, tenantName: null };
  const list = await res.json();
  const first = Array.isArray(list) && list.length > 0 ? list[0] : null;
  return { tenantId: first?.tenantId ?? null, tenantName: first?.tenantName ?? null };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);
  const route = url.pathname.split("/").pop();

  if (notConfigured()) {
    return json({ error: "not_configured", message: "Xero secrets are not set." }, 503);
  }

  try {
    // 1) Build consent URL
    if (route === "start") {
      const state = crypto.randomUUID();
      const authUrl = new URL(XERO_AUTH);
      authUrl.searchParams.set("response_type", "code");
      authUrl.searchParams.set("client_id", clientId);
      authUrl.searchParams.set("redirect_uri", redirectUri);
      authUrl.searchParams.set("scope", SCOPES);
      authUrl.searchParams.set("state", state);
      return json({ url: authUrl.toString(), state });
    }

    // 2) Handle Xero redirect
    if (route === "callback") {
      const code = url.searchParams.get("code");
      const err = url.searchParams.get("error");
      if (err || !code) {
        return Response.redirect(`${APP_DEEP_LINK}?status=error`, 302);
      }
      const tokens = await exchangeCode(code);
      const tenant = await fetchTenant(tokens.access_token);
      const expiresAt = new Date(Date.now() + (tokens.expires_in ?? 1800) * 1000).toISOString();

      const { error } = await admin().from("xero_connections").upsert(
        {
          company_key: COMPANY_KEY,
          tenant_id: tenant.tenantId,
          tenant_name: tenant.tenantName,
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_at: expiresAt,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "company_key" },
      );
      if (error) return Response.redirect(`${APP_DEEP_LINK}?status=error`, 302);
      return Response.redirect(`${APP_DEEP_LINK}?status=connected`, 302);
    }

    // 3) Refresh stored token
    if (route === "refresh") {
      const db = admin();
      const { data: conn } = await db
        .from("xero_connections")
        .select("refresh_token")
        .eq("company_key", COMPANY_KEY)
        .maybeSingle();
      if (!conn?.refresh_token) return json({ error: "not_connected" }, 409);

      const tokens = await refreshToken(conn.refresh_token);
      const expiresAt = new Date(Date.now() + (tokens.expires_in ?? 1800) * 1000).toISOString();
      await db.from("xero_connections").update({
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token ?? conn.refresh_token,
        expires_at: expiresAt,
        updated_at: new Date().toISOString(),
      }).eq("company_key", COMPANY_KEY);
      return json({ expires_at: expiresAt });
    }

    return json({ error: "unknown_route" }, 404);
  } catch (e) {
    return json({ error: "xero_error", message: String(e) }, 500);
  }
});