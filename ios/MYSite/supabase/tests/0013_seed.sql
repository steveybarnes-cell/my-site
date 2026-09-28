-- Two firms that exist BEFORE 0013 runs, to prove the backfill.
insert into public.companies (id, name, slug) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'Smith Building', 'smith'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'Jones Roofing', 'jones');
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-0000-4000-8000-000000000001', 'steve@smith.test', '{"name":"Steve Smith"}'),
  ('22222222-0000-4000-8000-000000000002', 'jo@jones.test',    '{"name":"Jo Jones"}'),
  ('33333333-0000-4000-8000-000000000003', 'dan@new.test',     '{"full_name":"Dan Newman"}'),
  ('44444444-0000-4000-8000-000000000004', 'ed@new.test',      '{"name":"Ed Other"}'),
  ('55555555-0000-4000-8000-000000000005', 'sm@smith.test',    '{"name":"Sam Manager"}');
set app.role_change_authorised = 'on';
update public.profiles set company_id = 'aaaaaaaa-0000-4000-8000-000000000001', role = 'Admin'
 where id = '11111111-0000-4000-8000-000000000001';
update public.profiles set company_id = 'bbbbbbbb-0000-4000-8000-000000000002', role = 'Admin'
 where id = '22222222-0000-4000-8000-000000000002';
update public.profiles set company_id = 'aaaaaaaa-0000-4000-8000-000000000001', role = 'Site Manager'
 where id = '55555555-0000-4000-8000-000000000005';
reset app.role_change_authorised;
