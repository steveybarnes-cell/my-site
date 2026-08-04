# Receipts → Hubdoc: what to do

Two separate things were broken. The AI scan had a one-line bug. Hubdoc had no
code at all.

Work top to bottom — steps 1–2 are the scan fix and are independent of Hubdoc,
so you can stop after step 2 and have working receipt reading.

---

## Why the AI scan was failing

The `scan-receipt` function asked OpenAI for a model called `gpt-5.4-mini`.
That model ID doesn't exist. OpenAI rejects the request, the function returns a
502, and the app says it couldn't read the receipt.

The current models are `gpt-5.6-sol`, `gpt-5.6-terra` and `gpt-5.6-luna`. I've
switched it to **`gpt-5.6-terra`** — the balanced one. This isn't the place to
save a fraction of a penny; it's reading amounts that end up in your books.

Two changes beyond the swap:

- An **`OPENAI_MODEL`** secret overrides it, so the next time a model is renamed
  it's a one-line secret change rather than a code edit and a deploy.
- The error now names the model. The old message didn't, which is why this
  looked like "the AI is broken" rather than "that string is wrong".

---

## 1. Deploy the fixed scan function

Supabase → **Edge Functions → scan-receipt → Edit** → replace the whole body
with `scan-receipt.ts` → **Deploy**.

## 2. Test it

Scan a receipt in the app. Supplier, net, VAT, total and date should come back
filled in. If it still fails, the error will now include the model name — send
me that.

**Also fixed, separately:** `MaterialFormView` was creating the receipt record
but never passing the photo to the uploader, so the bucket stayed empty. The
row said a receipt existed; the image was still on the phone. That's why this
matters beyond tidiness — Hubdoc has nothing to send if the bytes never left.

---

## Why Hubdoc needs building rather than connecting

Hubdoc has **no public API**. There's no key to paste, no OAuth flow.

Every Hubdoc organisation is given a unique upload email address, and emailing
a document to it is the only supported programmatic route in. So "send to
Hubdoc" means: your backend emails the receipt as an attachment.

That means you need something that can send email. Supabase can't — its built-in
mailer only does auth emails. Hence Resend below.

---

## 3. Run migration 0008

Supabase → **SQL Editor** → paste `0008_hubdoc.sql` → **Run**.

Adds:

- `companies.hubdoc_email` — per company, because the database is multi-tenant
  now and one firm's receipts must never land in another's books
- `hubdoc_deliveries` — a record of what was sent. Email is fire-and-forget;
  nothing comes back to say a receipt arrived, so without this there's no way to
  answer "did that go?"
- A unique index so the same receipt can't be sent twice. A double-tap would
  otherwise put the same purchase into your bookkeeping twice, which is worse
  than not sending it — someone has to notice and unpick it.

Verified on Postgres 16: a tradesman can't change the address, a malformed
address is refused, and one company can't see another's settings or delivery log.

## 4. Set up Resend

1. Sign up at **resend.com**. Free tier is 3,000 emails/month, 100/day —
   comfortably more than a construction firm's receipts.
2. **Verify a domain.** Resend requires one; there's no sandbox sender. Use
   something you control — `mybuildltd.com` or similar. It's a few DNS records.
3. Create an **API key**.

## 5. Add two Supabase secrets

Supabase → **Edge Functions → Secrets**:

| Name | Value |
|---|---|
| `RESEND_API_KEY` | the key from step 4 |
| `HUBDOC_FROM_EMAIL` | e.g. `receipts@yourverifieddomain.com` |

`HUBDOC_FROM_EMAIL` must be on the domain you verified, or Resend refuses to send.

## 6. Deploy the send-to-hubdoc function

Supabase → **Edge Functions → Deploy a new function** → name it exactly
**`send-to-hubdoc`** → paste `send-to-hubdoc.ts` → Deploy.

## 7. Authorise the sender in Hubdoc

Some Hubdoc organisations restrict which addresses can email documents in. If
yours does, add `HUBDOC_FROM_EMAIL` to the allowed senders — otherwise Hubdoc
silently drops them and nothing tells you.

Worth testing by emailing that address manually first.

## 8. Enter the Hubdoc address in the app

Rebuild, then **Admin → Profile → Integrations → Hubdoc**. Paste your Hubdoc
upload address (find it in Hubdoc under Upload Document, or Organization
settings) and save.

Blank turns it off. Every company that hasn't set one is unaffected — the send
call no-ops quietly rather than erroring at a tradesman who can't fix it.

## 9. Test end to end

Scan a receipt → save → it should appear in Hubdoc within a minute, and the
**delivered** count on that settings card should tick up.

---

## Something you should know about Xero

While tracing this I read `AppStore.sendToXero`. It doesn't push anything to
Xero. It waits 1.4 seconds, sets the status to "synced" and invents a reference
of the form `XERO-A1B2C3`.

That's demo scaffolding, not an integration. The screen says the receipt went to
Xero and it didn't. Your real Xero connection works — `xero-push-invoice`
exists and the OAuth flow is live — but this particular path is a placeholder
wired to a timer.

Worth fixing before anyone relies on it for a VAT return. Say the word and I'll
do it as its own job.
