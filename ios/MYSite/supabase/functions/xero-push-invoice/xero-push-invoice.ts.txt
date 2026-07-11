// Pushes an approved weekly submission into Xero as a draft ACCREC invoice.
//
// POST /xero-push-invoice  (verify_jwt on — only signed-in admins call this)
// Body: {
//   contactName: string,
//   reference?: string,
//   lineItems: { description: string, quantity: number, unitAmount: number, accountCode?: string }[]
// }
// Returns: { invoiceId, invoiceNumber, status } or { error }.
//
// Uses stored Xero tokens (auto-refreshing when expired) from public.xero_connections.

import { createClient } from "jsr:@supabase/supabase-js@2";

const XERO_TOKEN = "https://identity.xero.com/connect/token";
const XERO_INVOICES = "https://api.xero.com/api.xro/2.0/Invoices";
const COMPANY_KEY = "mpg";
const DEFAULT_ACCOUNT = "200";

const clientId = Deno.env.get("XERO_CLIENT_ID") ?? "";
const clientSecret = Deno.env.get("XERO_CLIENT_SECRET") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

async function refreshIfNeeded(db: ReturnType<typeof admin>) {
  const { data: conn } = await db
    .from("xero_connections")
    .select("access_token, refresh_token, tenant_id, expires_at")
    .eq("company_key", COMPANY_KEY)
    .maybeSingle();
  if (!conn?.access_token || !conn?.tenant_id) return null;

  const expiresAt = conn.expires_at ? new Date(conn.expires_at).getTime() : 0;
  if (Date.now() < expiresAt - 60_000) return conn;

  // Refresh
  const res = await fetch(XERO_TOKEN, {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(`${clientId}:${clientSecret}`),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: conn.refresh_token,
    }),
  });
  if (!res.ok) return null;
  const tokens = await res.json();
  const newExpiry = new Date(Date.now() + (tokens.expires_in ?? 1800) * 1000).toISOString();
  await db.from("xero_connections").update({
    access_token: tokens.access_token,
    refresh_token: tokens.refresh_token ?? conn.refresh_token,
    expires_at: newExpiry,
    updated_at: new Date().toISOString(),
  }).eq("company_key", COMPANY_KEY);
  return { ...conn, access_token: tokens.access_token };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const body = await req.json();
    const contactName: string = body.contactName ?? "";
    const reference: string | undefined = body.reference;
    const lineItems: Array<Record<string, unknown>> = body.lineItems ?? [];
    if (!contactName || lineItems.length === 0) {
      return json({ error: "invalid_request", message: "contactName and lineItems required" }, 400);
    }

    const db = admin();
    const conn = await refreshIfNeeded(db);
    if (!conn) return json({ error: "not_connected", message: "Xero is not connected." }, 409);

    const payload = {
      Invoices: [
        {
          Type: "ACCREC",
          Contact: { Name: contactName },
          Reference: reference ?? "",
          Status: "DRAFT",
          LineAmountTypes: "Exclusive",
          LineItems: lineItems.map((li) => ({
            Description: String(li.description ?? "Work"),
            Quantity: Number(li.quantity ?? 1),
            UnitAmount: Number(li.unitAmount ?? 0),
            AccountCode: String(li.accountCode ?? DEFAULT_ACCOUNT),
          })),
        },
      ],
    };

    const res = await fetch(XERO_INVOICES, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${conn.access_token}`,
        "Xero-tenant-id": String(conn.tenant_id),
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    const result = await res.json();
    if (!res.ok) {
      return json({ error: "xero_rejected", detail: result }, 502);
    }
    const inv = result?.Invoices?.[0];
    return json({
      invoiceId: inv?.InvoiceID ?? null,
      invoiceNumber: inv?.InvoiceNumber ?? null,
      status: inv?.Status ?? "DRAFT",
    });
  } catch (e) {
    return json({ error: "xero_error", message: String(e) }, 500);
  }
});