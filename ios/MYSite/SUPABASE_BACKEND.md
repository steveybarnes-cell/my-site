# Supabase Backend

This project uses the managed Backend workspace for Supabase Edge Functions.

- `supabase/functions/<name>/index.ts` contains named backend endpoints.
- Function secrets are stored in 10x and synced to Supabase through Backend.
- Do not turn this into an open HTTP proxy.
