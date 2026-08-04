# MY Site — going live as a multi-tenant product

What's built, what's verified, and what still needs you.

---

## Built and verified today

### Subscriptions — `0012_subscriptions.sql`

A `subscriptions` table per company: plan, status, seats, Stripe ids, period end,
trial end, and a per-company grace period. Companies gain branding columns and an
optional subdomain.

**Billing fails open, deliberately.** If a subscription row is missing, a webhook
hasn't arrived, or Stripe is having a bad day, the company keeps working. A hard
lockout means a card declining at 3am stops a bricklayer recording the day he has
just worked — and that record is gone, because he won't retype it on Monday.
Losing a customer's data to protect your revenue is the wrong way round.

Lapsed companies go read-only after the grace period, and even then only for
**new setup** — sites and allocations. Day sheets, work logs and clock-ins keep
writing regardless. A billing dispute between two companies is no reason for a
tradesman to lose his week.

Seats are counted and surfaced, never enforced. A firm that hires a sixth man on a
five-seat plan should be invoiced for him, not have him unable to clock on.

### Isolation test — `isolation_test.sql`, `run_isolation_test.sh`

Two companies, three users each, real data in both. Then it reads everything as
six different users and asserts nothing crosses. **36 assertions, all passing.**

It covers every table and view, both storage layouts, direct access by guessed
uuid, cross-company writes, a user with no company at all, and a sweep proving
every table has row-level security switched on — including `storage.objects`,
which lives outside the public schema and is easy to miss.

Run it before every deploy:

```bash
./run_isolation_test.sh path/to/migrations
```

Non-zero exit means don't ship.

Writing it found two things worth knowing. My Postgres stand-in had
`storage.foldername` returning the filename as a path segment, which shifts every
index in the storage policies by one — the test would have passed while proving
nothing. And my first version used a transaction-scoped session variable, so every
query ran as nobody and every count came back zero, which looks exactly like
perfect isolation. **A green isolation test is worthless unless you've watched it
go red.** Both are fixed and both now fail loudly.

Your actual policies came out clean, including the storage bucket — which is where
multi-tenant apps usually leak.

### Stripe webhook — `stripe-webhook.ts.txt`

Verifies Stripe's signature over the raw body, maps Stripe's statuses onto ours,
and writes the subscription row. Reads the subscription back from Stripe rather
than trusting the event payload, because events arrive out of order and a late
"created" would otherwise roll a company backwards.

Signature verification is tested — `node sigtest.mjs` — across seven cases:
genuine, wrong secret, tampered body, replayed old signature, missing field, empty
header, garbage. All correct.

**Deploy it with `verify_jwt` OFF.** Stripe is not a signed-in user and has no
Supabase token. Leaving JWT on is the most common reason a webhook silently 401s
for weeks while everyone assumes billing works.

---

## Still to do — yours

### 1. Decide the Apple question first

It changes everything downstream. Apple requires In-App Purchase for digital
services consumed in an app; there's a long-standing carve-out for business
software bought outside it, which is how Slack, Xero and QuickBooks work. Which
side you fall on depends on current guidelines rather than my memory of them, and
it's worth an hour of professional advice against 30% of revenue.

The safer shape, and the one those companies use: sign-up and payment on your
website, app free to download, "requires an account" in the listing.

### 2. Stripe

Create the account, define the plans, and add two secrets in Supabase:
`STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`. Set `client_reference_id` to the
company's uuid when you create a checkout session — without it there's no way to
know whose subscription an event belongs to, and the function drops it rather than
guessing.

I can't do this part: it needs your business details and bank account, and I don't
create accounts or handle payment credentials.

### 3. Hosting

GitHub Pages is fine for testing and wrong for a product — no custom domain
control worth having, nothing server-side. Cloudflare Pages or Vercel, a real
domain, and wildcard DNS if you want `acme.mysite.co.uk` per customer.

### 4. Backups

Supabase's free tier has no point-in-time recovery. The first time a customer
deletes a site by accident, that's the difference between a phone call and losing
them. Paid tier before the first paying customer, not after.

### 5. The paperwork

- A data processing agreement with each customer, and one with Supabase
- UK or EU data residency
- A working export-and-delete for a company's entire dataset
- Privacy policy and App Store labels that are exact about **location** — you're
  selling a tool that records where people are and how long they work, and each
  customer needs to be able to disclose that to their own staff. That obligation
  lands on you as the vendor.

### 6. Before the first paying customer

- Rotate the deprecated Supabase legacy keys — rotating them later breaks every
  installed app at once
- A penetration test by someone who isn't me
- Error monitoring, so you find out a customer is broken before they ring you

---

## Order I'd do it in

1. Apple question — it's the only one that can invalidate the others
2. Run 0010, 0011, 0012 on your database
3. Stripe account and plans, secrets in Supabase, deploy the webhook
4. Domain and proper hosting
5. Supabase paid tier for backups
6. Paperwork and key rotation
7. Pen test
8. First customer

Steps 2 and 3 are days. Steps 5 to 7 are the ones that get skipped when someone
wants to go live this week, and they're the ones that cost you a customer's data
or a regulator's attention.
