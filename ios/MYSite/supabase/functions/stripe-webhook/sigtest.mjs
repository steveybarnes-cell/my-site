// Extract the verifier from the function and prove it accepts a genuine
// Stripe signature and rejects the failure modes that matter.
import { readFileSync } from 'fs';
const src = readFileSync('stripe-webhook.ts.txt', 'utf8');
const start = src.indexOf('async function verifySignature');
const end = src.indexOf('async function stripeGet');
const body = src.slice(start, end).replace(/: (string|boolean|Promise<boolean>)/g, '')
  .replace(/ as \[string, string\]/g, '');
const verifySignature = (await import('data:text/javascript,' +
  encodeURIComponent(body + '\nexport { verifySignature };'))).verifySignature;

const secret = 'whsec_test_secret_value';
const payload = JSON.stringify({ id: 'evt_1', type: 'customer.subscription.updated' });

async function sign(ts, pl, sec) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(sec),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${ts}.${pl}`));
  return Array.from(new Uint8Array(mac)).map(b => b.toString(16).padStart(2, '0')).join('');
}

const now = Math.floor(Date.now() / 1000);
const good = await sign(now, payload, secret);

const cases = [
  ['genuine signature accepted',        `t=${now},v1=${good}`,               payload, secret, true],
  ['wrong secret rejected',             `t=${now},v1=${good}`,               payload, 'whsec_wrong', false],
  ['tampered body rejected',            `t=${now},v1=${good}`,               payload + ' ', secret, false],
  ['replayed old signature rejected',   `t=${now - 3600},v1=${await sign(now - 3600, payload, secret)}`, payload, secret, false],
  ['missing v1 rejected',               `t=${now}`,                          payload, secret, false],
  ['empty header rejected',             ``,                                  payload, secret, false],
  ['garbage signature rejected',        `t=${now},v1=deadbeef`,              payload, secret, false],
];

let failed = 0;
for (const [name, header, pl, sec, want] of cases) {
  const got = await verifySignature(pl, header, sec);
  const ok = got === want;
  if (!ok) failed++;
  console.log(`${ok ? 'pass ' : 'FAIL '} ${name}`);
}
console.log(failed ? `\n${failed} FAILED` : '\nsignature verification: all cases correct');
process.exit(failed ? 1 : 0);
