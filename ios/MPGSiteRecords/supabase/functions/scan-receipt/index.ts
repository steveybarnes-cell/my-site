// scan-receipt: OpenAI vision receipt extraction for MPG Site Records.
// Receives a base64 image, returns structured purchase data as JSON.
// The OpenAI API key stays server-side (Supabase secret) and never reaches the app.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ScanResult {
  supplier: string;
  description: string;
  costExVat: number | null;
  vatAmount: number | null;
  total: number | null;
  date: string | null; // ISO yyyy-MM-dd
  confidence: "high" | "medium" | "low";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return json({ error: "OpenAI is not configured on the server." }, 500);
    }

    const body = await req.json().catch(() => null);
    const imageBase64: string | undefined = body?.imageBase64;
    const mimeType: string = body?.mimeType ?? "image/jpeg";
    if (!imageBase64 || typeof imageBase64 !== "string") {
      return json({ error: "Missing imageBase64 in request body." }, 400);
    }

    const dataURL = imageBase64.startsWith("data:")
      ? imageBase64
      : `data:${mimeType};base64,${imageBase64}`;

    const developerPrompt =
      "You extract structured purchase data from UK construction receipts and " +
      "supplier invoices (e.g. Screwfix, Toolstation, Travis Perkins, Jewson, " +
      "Wickes, B&Q). Return ONLY a compact JSON object with these exact keys: " +
      "supplier (string, the merchant/store name), description (string, a short " +
      "summary of the main items purchased), costExVat (number, net amount before " +
      "VAT in GBP), vatAmount (number, VAT amount in GBP), total (number, gross " +
      "total in GBP), date (string, purchase date as yyyy-MM-dd), confidence " +
      "(one of high, medium, low). Use null for any value you cannot read. " +
      "If only the gross total and VAT are visible, compute costExVat = total - " +
      "vatAmount. If only the total is visible with standard 20% VAT, set " +
      "costExVat = round(total / 1.2, 2) and vatAmount = total - costExVat. " +
      "Do not include currency symbols, commas or any text outside the JSON.";

    const payload = {
      model: "gpt-5.4-mini",
      max_completion_tokens: 600,
      response_format: { type: "json_object" },
      messages: [
        { role: "developer", content: developerPrompt },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Extract the purchase data from this receipt.",
            },
            { type: "image_url", image_url: { url: dataURL } },
          ],
        },
      ],
    };

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      const detail = await resp.text();
      return json({ error: `OpenAI request failed: ${detail}` }, 502);
    }

    const completion = await resp.json();
    const content: string =
      completion?.choices?.[0]?.message?.content ?? "{}";

    let parsed: Partial<ScanResult> = {};
    try {
      parsed = JSON.parse(content);
    } catch {
      parsed = {};
    }

    const result: ScanResult = {
      supplier: str(parsed.supplier),
      description: str(parsed.description),
      costExVat: num(parsed.costExVat),
      vatAmount: num(parsed.vatAmount),
      total: num(parsed.total),
      date: str(parsed.date) || null,
      confidence:
        parsed.confidence === "high" ||
        parsed.confidence === "medium" ||
        parsed.confidence === "low"
          ? parsed.confidence
          : "low",
    };

    // Backfill net/VAT when possible so the app always gets a usable figure.
    if (result.costExVat == null && result.total != null) {
      if (result.vatAmount != null) {
        result.costExVat = round(result.total - result.vatAmount);
      } else {
        result.costExVat = round(result.total / 1.2);
        result.vatAmount = round(result.total - result.costExVat);
      }
    }
    if (result.vatAmount == null && result.costExVat != null) {
      result.vatAmount = round(result.costExVat * 0.2);
    }

    return json(result, 200);
  } catch (e) {
    return json({ error: `Unexpected error: ${String(e)}` }, 500);
  }
});

function str(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

function num(v: unknown): number | null {
  if (typeof v === "number" && isFinite(v)) return v;
  if (typeof v === "string") {
    const n = parseFloat(v.replace(/[^0-9.\-]/g, ""));
    return isFinite(n) ? n : null;
  }
  return null;
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}