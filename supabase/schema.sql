-- KIT (Kosadilok Institute of Technology) — โครงสร้างฐานข้อมูล + RLS
-- รันทั้งไฟล์ใน Supabase > SQL Editor (รันซ้ำได้)

-- 1) ตารางเก็บเนื้อหาเว็บไซต์: เมนู / หน้าเว็บ / กิจกรรมปฏิทิน / ตั้งค่า (+หน้าแรก)
create table if not exists public.site_docs (
  key        text primary key check (key in ('menu','pages','events','settings','campus','fgroups','faculties','majors','programs')),
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  constraint site_docs_shape check (
    (key in ('settings','campus') and jsonb_typeof(data) = 'object') or
    (key not in ('settings','campus') and jsonb_typeof(data) = 'array')
  )
);

-- รองรับฐานข้อมูลที่สร้างไว้ก่อนมีแผนผังสถาบัน (key 'campus')
alter table public.site_docs drop constraint if exists site_docs_key_check;
alter table public.site_docs add  constraint site_docs_key_check check (key in ('menu','pages','events','settings','campus','fgroups','faculties','majors','programs'));
alter table public.site_docs drop constraint if exists site_docs_shape;
alter table public.site_docs add  constraint site_docs_shape check (
  (key in ('settings','campus') and jsonb_typeof(data) = 'object') or
  (key not in ('settings','campus') and jsonb_typeof(data) = 'array')
);

-- 2) รายชื่อทีมงานที่มีสิทธิ์แก้ไข (เพิ่ม/ลบได้เฉพาะผ่าน SQL Editor เท่านั้น)
create table if not exists public.staff (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.site_docs enable row level security;
alter table public.staff     enable row level security;

-- 3) ฟังก์ชันตรวจสิทธิ์ทีมงาน
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.staff where user_id = auth.uid());
$$;
revoke all on function public.is_staff() from public, anon;
grant execute on function public.is_staff() to authenticated;

-- 4) สิทธิ์ระดับตาราง: anon ไม่แตะตารางตรง ๆ เลย
revoke all on public.site_docs from anon, authenticated;
revoke all on public.staff     from anon, authenticated;
grant select, insert, update, delete on public.site_docs to authenticated;
grant select on public.staff to authenticated;

-- 5) นโยบาย RLS
drop policy if exists site_docs_staff_select on public.site_docs;
drop policy if exists site_docs_staff_insert on public.site_docs;
drop policy if exists site_docs_staff_update on public.site_docs;
drop policy if exists site_docs_staff_delete on public.site_docs;
create policy site_docs_staff_select on public.site_docs for select to authenticated using (public.is_staff());
create policy site_docs_staff_insert on public.site_docs for insert to authenticated with check (public.is_staff());
create policy site_docs_staff_update on public.site_docs for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy site_docs_staff_delete on public.site_docs for delete to authenticated using (public.is_staff());

drop policy if exists staff_read_self on public.staff;
create policy staff_read_self on public.staff for select to authenticated using (user_id = auth.uid());

-- ตัวช่วย (ภายในเท่านั้น): แถวที่เผยแพร่ของเอกสารแบบ array และสังกัดต้นสังกัดที่เผยแพร่แล้ว
create or replace function public._pub_rows(p_key text, p_parent text, p_ids text[])
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(r.v order by r.n), '[]'::jsonb)
  from jsonb_array_elements(
         case when jsonb_typeof((select data from public.site_docs where key = p_key)) = 'array'
              then (select data from public.site_docs where key = p_key) else '[]'::jsonb end
       ) with ordinality as r(v, n)
  where r.v->>'status' = 'published'
    and (p_parent is null or (r.v->>p_parent) = any (p_ids));
$$;
revoke all on function public._pub_rows(text, text, text[]) from public, anon, authenticated;

-- 6) ผู้เข้าชมทั่วไป: อ่านได้เฉพาะ "สิ่งที่เผยแพร่แล้ว" ผ่านฟังก์ชันนี้เท่านั้น (ฉบับร่างและเมนูที่ซ่อนไม่ถูกส่งออก)
create or replace function public.get_public_site()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_pages  jsonb;
  v_ids    text[];
  v_menu   jsonb;
  v_events jsonb;
  v_set    jsonb;
  v_campus jsonb;
  v_fg     jsonb;
  v_fa     jsonb;
  v_mj     jsonb;
  v_pg     jsonb;
begin
  select coalesce(jsonb_agg(p.v order by p.n), '[]'::jsonb) into v_pages
  from jsonb_array_elements(coalesce((select data from public.site_docs where key = 'pages'), '[]'::jsonb)) with ordinality as p(v, n)
  where p.v->>'status' = 'published';

  select coalesce(array_agg(p.v->>'id'), '{}'::text[]) into v_ids
  from jsonb_array_elements(v_pages) as p(v);

  select coalesce(jsonb_agg(m.v order by m.n), '[]'::jsonb) into v_menu
  from jsonb_array_elements(coalesce((select data from public.site_docs where key = 'menu'), '[]'::jsonb)) with ordinality as m(v, n)
  where coalesce(m.v->>'show', 'true') <> 'false'
    and (coalesce(m.v->>'kind', '') <> 'cms' or (m.v->>'pageId') = any (v_ids));

  select coalesce(jsonb_agg(e.v order by e.n), '[]'::jsonb) into v_events
  from jsonb_array_elements(coalesce((select data from public.site_docs where key = 'events'), '[]'::jsonb)) with ordinality as e(v, n)
  where e.v->>'status' = 'published';

  select coalesce((select data from public.site_docs where key = 'settings'), '{}'::jsonb) into v_set;

  -- แผนผังสถาบัน: ส่งเฉพาะสถานที่ที่ไม่ได้ซ่อน
  select coalesce((select data from public.site_docs where key = 'campus'), '{}'::jsonb) into v_campus;
  if jsonb_typeof(v_campus) = 'object' then
    v_campus := jsonb_set(v_campus, '{places}', case when jsonb_typeof(v_campus->'places') = 'array' then
      coalesce((select jsonb_agg(c.v order by c.n)
                from jsonb_array_elements(v_campus->'places') with ordinality as c(v, n)
                where coalesce(c.v->>'show', 'true') <> 'false'), '[]'::jsonb)
      else '[]'::jsonb end);
  end if;

  -- คณะและหลักสูตร: ต้องเผยแพร่ครบทุกระดับต้นสังกัด (กลุ่ม → คณะ → สาขา → หลักสูตร)
  v_fg := public._pub_rows('fgroups', null, null);
  v_fa := public._pub_rows('faculties', 'groupId',
            (select coalesce(array_agg(x->>'id'), '{}'::text[]) from jsonb_array_elements(v_fg) x));
  v_mj := public._pub_rows('majors', 'facultyId',
            (select coalesce(array_agg(x->>'id'), '{}'::text[]) from jsonb_array_elements(v_fa) x));
  v_pg := public._pub_rows('programs', 'majorId',
            (select coalesce(array_agg(x->>'id'), '{}'::text[]) from jsonb_array_elements(v_mj) x));

  return jsonb_build_object('menu', v_menu, 'pages', v_pages, 'events', v_events, 'settings', v_set, 'campus', v_campus,
                            'fgroups', v_fg, 'faculties', v_fa, 'majors', v_mj, 'programs', v_pg);
end;
$$;
revoke all on function public.get_public_site() from public;
grant execute on function public.get_public_site() to anon, authenticated;

-- 7) Realtime: ให้หลังบ้านหลายเครื่องเห็นการแก้ไขตรงกัน (ส่งเฉพาะให้ผู้ที่ผ่าน RLS)
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'site_docs') then
    alter publication supabase_realtime add table public.site_docs;
  end if;
end $$;

-- 8) Storage: ที่เก็บรูปแผนผังสถาบัน (bucket สาธารณะสำหรับอ่านรูป; อัปโหลด/แก้/ลบได้เฉพาะทีมงาน)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('campus', 'campus', true, 5242880, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update
  set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists campus_staff_select on storage.objects;
drop policy if exists campus_staff_insert on storage.objects;
drop policy if exists campus_staff_update on storage.objects;
drop policy if exists campus_staff_delete on storage.objects;
create policy campus_staff_select on storage.objects for select to authenticated using (bucket_id = 'campus' and public.is_staff());
create policy campus_staff_insert on storage.objects for insert to authenticated with check (bucket_id = 'campus' and public.is_staff());
create policy campus_staff_update on storage.objects for update to authenticated using (bucket_id = 'campus' and public.is_staff()) with check (bucket_id = 'campus' and public.is_staff());
create policy campus_staff_delete on storage.objects for delete to authenticated using (bucket_id = 'campus' and public.is_staff());

-- 9) Storage: คลังสื่อรูปคณะ/ดอกไม้ประจำคณะ (bucket 'media')
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 5242880, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update
  set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists media_staff_select on storage.objects;
drop policy if exists media_staff_insert on storage.objects;
drop policy if exists media_staff_update on storage.objects;
drop policy if exists media_staff_delete on storage.objects;
create policy media_staff_select on storage.objects for select to authenticated using (bucket_id = 'media' and public.is_staff());
create policy media_staff_insert on storage.objects for insert to authenticated with check (bucket_id = 'media' and public.is_staff());
create policy media_staff_update on storage.objects for update to authenticated using (bucket_id = 'media' and public.is_staff()) with check (bucket_id = 'media' and public.is_staff());
create policy media_staff_delete on storage.objects for delete to authenticated using (bucket_id = 'media' and public.is_staff());
