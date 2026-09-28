\set ON_ERROR_STOP 1
-- act(uid) = become that signed-in user, exactly as PostgREST would.
create or replace function pg_temp.act(uid text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid, false);
  perform set_config('request.jwt.claim.role', 'authenticated', false);
end $$;
create temp table result (n serial, name text, ok boolean, detail text);
grant all on result to authenticated, anon; grant usage on sequence result_n_seq to authenticated, anon;
create or replace function pg_temp.chk(name text, ok boolean, detail text default '') returns void
language sql as $$ insert into result(name, ok, detail) values (name, coalesce(ok,false), detail) $$;
-- expect_err(sql, fragment): the call must fail with a message containing fragment.
create or replace function pg_temp.err(q text) returns text language plpgsql as $$
begin execute q; return null; exception when others then return sqlerrm; end $$;
\set STEVE '11111111-0000-4000-8000-000000000001'
\set JO    '22222222-0000-4000-8000-000000000002'
\set DAN   '33333333-0000-4000-8000-000000000003'
\set ED    '44444444-0000-4000-8000-000000000004'
\set SAM   '55555555-0000-4000-8000-000000000005'

-- ---------- backfill ----------
select pg_temp.chk('existing companies got a 6-char code',
  (select bool_and(join_code ~ '^[ACDEFGHJKMNPQRTUVWXY34679]{6}$') and count(*) = 3 from companies));
insert into companies (name, slug) values ('Brand New Ltd', 'brand-new');
select pg_temp.chk('a new company gets a code automatically',
  (select join_code is not null from companies where slug = 'brand-new'));
select join_code as smith from companies where slug = 'smith' \gset
select join_code as jones from companies where slug = 'jones' \gset

-- ---------- admin reads his code; others cannot ----------
set role authenticated;
select pg_temp.act(:'STEVE');
select pg_temp.chk('admin reads his own company code', company_join_code() = :'smith');
select pg_temp.act(:'SAM');
select pg_temp.chk('a site manager cannot read the code',
  pg_temp.err('select company_join_code()') like 'Only an admin%');
select pg_temp.act(:'DAN');
select pg_temp.chk('a new signup cannot read any code',
  pg_temp.err('select company_join_code()') like 'Only an admin%');
select pg_temp.chk('join_requests cannot be inserted directly',
  pg_temp.err($q$insert into join_requests(user_id, company_id) values ('33333333-0000-4000-8000-000000000003','aaaaaaaa-0000-4000-8000-000000000001')$q$) like '%permission denied%');

-- ---------- asking ----------
select pg_temp.chk('an unknown code is refused in words',
  pg_temp.err($q$select request_to_join('ZZZZZZ')$q$) like 'That company code was not recognised%');
select pg_temp.chk('a sloppy code (lower case, spaces, dash) still finds the firm',
  request_to_join(lower(substr(:'smith',1,3)) || ' - ' || lower(substr(:'smith',4))) = 'Smith Building');
select pg_temp.chk('his waiting screen shows Pending + the firm name',
  (select status = 'Pending' and company_name = 'Smith Building' from my_join_request()));
select pg_temp.chk('he still has no company while waiting',
  (select company_id is null from profiles where id = auth.uid()));
select created_at as first_ask from my_join_request() \gset
select request_to_join(:'smith');
select pg_temp.chk('asking the same firm again keeps his place, one request',
  (select count(*) from join_requests where status <> 'Withdrawn') = 1
  and (select created_at = :'first_ask'::timestamptz from my_join_request()));

select pg_temp.act(:'ED');
select request_to_join(:'jones');

-- ---------- who sees what ----------
select pg_temp.act(:'STEVE');
select pg_temp.chk('Smith admin sees Dan waiting, with name and email',
  (select count(*) = 1 and bool_and(name = 'Dan Newman' and email = 'dan@new.test')
     from pending_join_requests()));
select pg_temp.chk('Smith admin does NOT see Ed, who asked Jones',
  not exists (select 1 from pending_join_requests() where email = 'ed@new.test'));
select pg_temp.chk('the leak is closed: Smith admin cannot read Ed''s profile',
  not exists (select 1 from profiles where id = :'ED'));
select pg_temp.chk('Smith admin CAN read Dan''s profile (he asked them)',
  exists (select 1 from profiles where id = :'DAN'));
select pg_temp.chk('iPhone pending_signups view shows only Dan',
  (select array_agg(email) = array['dan@new.test'] from pending_signups));
reset role;
select id as ed_req from join_requests where user_id = :'ED' and status = 'Pending' \gset
select id as dan_req from join_requests where user_id = :'DAN' and status = 'Pending' \gset
set role authenticated;
select pg_temp.act(:'STEVE');
select pg_temp.chk('Smith admin cannot decide a Jones request (reported as not found)',
  pg_temp.err(format('select decide_join_request(%L, true)', :'ed_req')) = 'That request was not found.');
select pg_temp.chk('Smith admin cannot adopt Ed who never asked them',
  pg_temp.err(format('select adopt_user_into_company(%L)', :'ED')) like 'That person has not asked to join your company%');
select pg_temp.act(:'SAM');
select pg_temp.chk('a site manager cannot approve',
  pg_temp.err(format('select decide_join_request(%L, true)', :'dan_req')) like 'Only an admin%');
select pg_temp.act(:'DAN');
select pg_temp.chk('Dan cannot approve himself',
  pg_temp.err(format('select decide_join_request(%L, true)', :'dan_req')) like 'Only an admin%');
select pg_temp.chk('Dan cannot see the admin queue',
  pg_temp.err('select * from pending_join_requests()') like 'Only an admin%');

-- ---------- approve ----------
select pg_temp.act(:'STEVE');
select decide_join_request(:'dan_req', true, 'Site Manager');
reset role;
select pg_temp.chk('approving puts him in the company with the chosen role',
  (select company_id = 'aaaaaaaa-0000-4000-8000-000000000001' and role = 'Site Manager'
     from profiles where id = :'DAN'));
select pg_temp.chk('the request records who approved it and the role',
  (select status = 'Approved' and role = 'Site Manager' and decided_by = :'STEVE' and decided_at is not null
     from join_requests where id = :'dan_req'));
set role authenticated;
select pg_temp.act(:'STEVE');
select pg_temp.chk('deciding twice is refused',
  pg_temp.err(format('select decide_join_request(%L, false)', :'dan_req')) like 'That request has already been dealt with%');
select pg_temp.chk('the queue is empty again', not exists (select 1 from pending_join_requests()));
select pg_temp.act(:'DAN');
select pg_temp.chk('Dan now sees Approved', (select status = 'Approved' from my_join_request()));
select pg_temp.chk('Dan cannot ask to join anyone else now',
  pg_temp.err(format('select request_to_join(%L)', :'jones')) like 'Your account already belongs%');

-- ---------- decline ----------
select pg_temp.act(:'JO');
select decide_join_request(:'ed_req', false);
select pg_temp.act(:'ED');
select pg_temp.chk('Ed sees Declined, with the firm name',
  (select status = 'Declined' and company_name = 'Jones Roofing' from my_join_request()));
reset role;
select pg_temp.chk('declining leaves him without a company',
  (select company_id is null from profiles where id = :'ED'));
set role authenticated;
select pg_temp.act(:'JO');
select pg_temp.chk('after declining, Jones admin can no longer read Ed''s profile',
  not exists (select 1 from profiles where id = :'ED'));
select pg_temp.act(:'ED');
select pg_temp.chk('Ed can ask a different firm after being declined',
  request_to_join(:'smith') = 'Smith Building');

-- ---------- switching firms while waiting ----------
select request_to_join(:'jones');
select pg_temp.chk('asking Jones instead withdraws the Smith request',
  (select count(*) from join_requests where status = 'Pending') = 1
  and (select company_name from my_join_request()) = 'Jones Roofing');
select pg_temp.act(:'STEVE');
select pg_temp.chk('...and it is gone from Smith''s queue', not exists (select 1 from pending_join_requests()));

-- ---------- invite codes still skip the queue, and close the request ----------
select create_role_invite('Tradesman') as code \gset
select pg_temp.act(:'ED');
select redeem_role_invite(:'code');
reset role;
select pg_temp.chk('an invite code still works and puts him in the inviting firm',
  (select company_id = 'aaaaaaaa-0000-4000-8000-000000000001' from profiles where id = :'ED'));
select pg_temp.chk('...and his open Jones request was closed, not left dangling',
  not exists (select 1 from join_requests where user_id = :'ED' and status = 'Pending'));

-- ---------- iPhone "Add to company" path still works for a real requester ----------
insert into auth.users (id, email, raw_user_meta_data) values
  ('66666666-0000-4000-8000-000000000006', 'fay@new.test', '{"name":"Fay Fresh"}');
set role authenticated;
select pg_temp.act('66666666-0000-4000-8000-000000000006');
select request_to_join(:'smith');
select pg_temp.act(:'STEVE');
select adopt_user_into_company('66666666-0000-4000-8000-000000000006', 'Tradesman');
reset role;
select pg_temp.chk('iPhone Add-to-company approves the request too',
  (select status = 'Approved' from join_requests where user_id = '66666666-0000-4000-8000-000000000006')
  and (select company_id is not null from profiles where id = '66666666-0000-4000-8000-000000000006'));

-- ---------- reset code ----------
insert into auth.users (id, email) values ('77777777-0000-4000-8000-000000000007', 'g@new.test');
set role authenticated;
select pg_temp.act(:'STEVE');
select reset_join_code() as newcode \gset
select pg_temp.chk('resetting gives a new code', :'newcode' <> :'smith');
select pg_temp.act('77777777-0000-4000-8000-000000000007');
select pg_temp.chk('the old code stops working',
  pg_temp.err(format('select request_to_join(%L)', :'smith')) like 'That company code was not recognised%');
select pg_temp.chk('the new one works', request_to_join(:'newcode') = 'Smith Building');
select pg_temp.act(:'SAM');
select pg_temp.chk('a site manager cannot reset it', pg_temp.err('select reset_join_code()') like 'Only an admin%');

-- ---------- anon has nothing ----------
reset role;
set role anon;
select pg_temp.chk('anon cannot call request_to_join',
  pg_temp.err($q$select request_to_join('X')$q$) like '%permission denied%');
reset role;

select case when ok then '  ok   ' else '  FAIL ' end || name || case when ok then '' else '  → ' || detail end from result order by n;
select count(*) filter (where ok) || ' passed, ' || count(*) filter (where not ok) || ' failed' from result;
