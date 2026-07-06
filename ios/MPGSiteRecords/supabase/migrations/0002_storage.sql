-- =====================================================================
-- MPG Site Records — Storage buckets
-- Run AFTER 0001_mpg_schema.sql in the Supabase SQL Editor.
--
-- One private bucket holds all site evidence (photos, receipts, supplier
-- invoices, documents). Access is controlled by RLS on storage.objects,
-- mirroring the app's privacy rules. Files are organised by path:
--     site-evidence/<site_id>/<user_id>/<filename>
-- so we can authorise on the folder segments.
-- =====================================================================

-- Create the private bucket (id = name = 'site-evidence').
insert into storage.buckets (id, name, public)
values ('site-evidence', 'site-evidence', false)
on conflict (id) do nothing;

-- Helper: is the current user allowed to touch this object's site?
-- Path convention: first folder segment = site_id, second = owner user_id.
-- storage.foldername(name) returns the path segments as a text[].

-- ---------- READ ----------
drop policy if exists evidence_read on storage.objects;
create policy evidence_read on storage.objects for select using (
  bucket_id = 'site-evidence'
  and (
    public.is_admin()
    or (storage.foldername(name))[2] = auth.uid()::text          -- own files
    or public.manages_site(((storage.foldername(name))[1])::uuid) -- site manager
  )
);

-- ---------- UPLOAD ----------
drop policy if exists evidence_insert on storage.objects;
create policy evidence_insert on storage.objects for insert with check (
  bucket_id = 'site-evidence'
  and (
    public.is_admin()
    or (storage.foldername(name))[2] = auth.uid()::text
  )
);

-- ---------- UPDATE (overwrite) ----------
drop policy if exists evidence_update on storage.objects;
create policy evidence_update on storage.objects for update using (
  bucket_id = 'site-evidence'
  and (
    public.is_admin()
    or (storage.foldername(name))[2] = auth.uid()::text
  )
);

-- ---------- DELETE (owner or admin) ----------
drop policy if exists evidence_delete on storage.objects;
create policy evidence_delete on storage.objects for delete using (
  bucket_id = 'site-evidence'
  and (
    public.is_admin()
    or (storage.foldername(name))[2] = auth.uid()::text
  )
);
