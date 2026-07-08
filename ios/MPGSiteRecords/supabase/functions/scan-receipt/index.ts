// scan-receipt: extract supplier, costs, VAT and date from a receipt photo.
// The OpenAI key stays server-side as a Supabase secret (OPENAI_API_KEY).
// Auth: requires a valid Supabase user JWT (verify_jwt = true).

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return json(
      { error: "OpenAI is not configured. Add OPENAI_API_KEY as a backend secret." },
      503,
    );
  }

  let payload: { image?: string; mimeType?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const image = (payload.image ?? "").trim();
  if (!image) return json({ error: "Missing 'image' (base64) in body" }, 400);

  const mimeType = payload.mimeType ?? "image/jpeg";
  const dataUrl = image.startsWith("data:")
    ? image
    : `data:${mimeType};base64,${image}`;

  const systemPrompt =
    "You are an expert at reading UK trade/construction receipts and supplier invoices. " +
    "Extract the purchase details from the image. Return ONLY a JSON object with these keys: " +
    "supplier (string, merchant/company name e.g. Screwfix), " +
    "description (string, short summary of items purchased), " +
    "costExVat (number, total NET amount excluding VAT in GBP), " +
    "vatAmount (number, total VAT in GBP), " +
    "total (number, gross total in GBP), " +
    "date (string, purchase date in ISO yyyy-MM-dd format), " +
    "confidence (number 0-1). " +
    "If VAT is not shown separately but a gross total and VAT rate exist, compute the split. " +
    "If a value is not present, use null. Do not include any text outside the JSON.";

  const body = {
    model: "gpt-5.4-mini",
    max_completion_tokens: 700,
    response_format: { type: "json_object" },
    messages: [
      { role: "developer", content: systemPrompt },
      {
        role: "user",
        content: [
          { type: "text", text: "Extract the receipt details as JSON." },
          { type: "image_url", image_url: { url: dataUrl } },
        ],
      },
    ],
  };

  let aiRes: Response;
  try {
    aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    return json({ error: `Failed to reach OpenAI: ${e}` }, 502);
  }

  if (!aiRes.ok) {
    const text = await aiRes.text();
    return json({ error: `OpenAI error ${aiRes.status}: ${text}` }, 502);
  }

  const data = await aiRes.json();
  const content: string = data?.choices?.[0]?.message?.content ?? "";
  if (!content) return json({ error: "OpenAI returned no content" }, 502);

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(content);
  } catch {
    return json({ error: "Could not parse receipt data", raw: content }, 502);
  }

  return json({ result: parsed });
});