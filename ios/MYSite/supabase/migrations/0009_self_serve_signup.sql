-- =====================================================================
-- MPG Site Records — 0009: a firm can sign itself up
-- Run AFTER 0008_hubdoc.sql.
--
-- Until now a company could only be created out of band —
-- `bootstrap_company` is revoked from `authenticated`, so someone had to run
-- SQL. A person who signed up landed with no company and saw an empty app
-- with no way forward and nothing telling them why.
--
-- This adds the missing front door. There are exactly two ways in, and the
-- app should offer both:
--
--   create_company()      the first person from a firm — becomes its Admin
--   redeem_role_invite()  everyone after them — already existed since 0005
--
-- The Hubdoc address is collected here rather than left to a settings screen,
-- because a company that never sets one has receipts going quietly nowhere,
-- and the moment someone is thinking about their firm's paperwork is the
-- moment they know the answer.
--
-- Safe to re-run.
-- =====================================================================

-- =====================================================================
-- 1. Turning a company name into a slug
--
-- Separate from create_company so it can be tested on its own, and so the
-- rules live in one place if they ever need changing.
-- =====================================================================

create or replace function public.company_slug_base(p_name text)
returns text language sql immutable set search_path = public as $$
  select coalesce(
    nullif(
      left(btrim(regexp_replace(lower(btrim(coalesce(p_name, ''))), '[^a-z0-9]+', '-', 'g'), '-'), 40),
      ''),
    'company')
$$;

-- =====================================================================
-- 2. Creating a company
--
-- Callable by any signed-in user, which sounds alarming and isn't: the only
-- thing a stranger can create is their own empty tenant, visible to nobody
-- but themselves. They cannot reach an existing company's data, because the
-- function refuses to run at all for anyone who already belongs to one — and
-- that same check is what caps it at one company per account.
--
-- What it deliberately does NOT do is let someone move. Leaving a company
-- would strand every record they had created in it, so the answer is no.
-- =====================================================================

create or replace function public.create_company(
  p_name         text,
  p_hubdoc_email text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_user    uuid := auth.uid();
  v_name    text := btrim(coalesce(p_name, ''));
  v_hubdoc  text := nullif(btrim(coalesce(p_hubdoc_email, '')), '');
  v_base    text;
  v_slug    text;
  v_company uuid;
  v_existing uuid;
  v_attempt int := 0;
begin
  if v_user is null then
    raise exception 'You must be signed in to create a company.' using errcode = '42501';
  end if;

  if length(v_name) < 2 then
    raise exception 'Please enter your company name.' using errcode = '22023';
  end if;
  if length(v_name) > 120 then
    raise exception 'That company name is too long.' using errcode = '22023';
  end if;

  if v_hubdoc is not null
     and v_hubdoc !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'That does not look like an email address.' using errcode = '22023';
  end if;

  -- The profile row is created by a trigger on signup, so its absence means
  -- something is wrong rather than that they are new.
  select company_id into strict v_existing from public.profiles where id = v_user;
  if v_existing is not null then
    raise exception
      'Your account already belongs to a company. Ask an admin there if you need a different role.'
      using errcode = '42501';
  end if;

  v_base := public.company_slug_base(v_name);

  -- Two firms called "Smith Building" is entirely plausible, so a clash is a
  -- normal event, not an error. Retry with a suffix rather than failing.
  -- Bounded so a pathological name can't spin.
  loop
    v_attempt := v_attempt + 1;
    v_slug := case when v_attempt = 1 then v_base else v_base || '-' || v_attempt end;
    begin
      insert into public.companies (name, slug, hubdoc_email)
      values (v_name, v_slug, v_hubdoc)
      returning id into v_company;
      exit;
    exception when unique_violation then
      if v_attempt >= 50 then
        raise exception 'Could not create a company with that name.' using errcode = '22023';
      end if;
    end;
  end loop;

  perform set_config('app.role_change_authorised', 'on', true);
  update public.profiles
     set company_id = v_company, role = 'Admin'
   where id = v_user;
  perform set_config('app.role_change_authorised', 'off', true);

  return v_company;
end $$;

revoke execute on function public.create_company(text, text) from anon;
grant execute on function public.create_company(text, text) to authenticated;

-- =====================================================================
-- 3. What the app needs before it can route
--
-- On launch the app has to decide between the normal UI and the onboarding
-- screen, and it cannot read `companies` to find out — the select policy
-- scopes that to your own company, which is precisely the thing you do not
-- have yet. So it asks this instead.
-- =====================================================================

create or replace function public.my_onboarding_state()
returns table (
  has_company  boolean,
  company_name text,
  role         user_role,
  needs_hubdoc boolean
) language sql stable security definer set search_path = public as $$
  select
    p.company_id is not null,
    c.name,
    p.role,
    p.company_id is not null and coalesce(c.hubdoc_email, '') = ''
  from public.profiles p
  left join public.companies c on c.id = p.company_id
  where p.id = auth.uid()
$$;

revoke execute on function public.my_onboarding_state() from anon;
grant execute on function public.my_onboarding_state() to authenticated;
