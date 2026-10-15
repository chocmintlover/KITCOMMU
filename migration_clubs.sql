-- ชมรมนักศึกษา: ย้ายฐานข้อมูล (รันซ้ำได้ ไม่ลบ/ไม่เขียนทับข้อมูลเดิม ไม่สร้างตารางใหม่)
-- 1) อนุญาตคีย์ใหม่ 'clubcats' และ 'clubs' ใน site_docs (รูปแบบข้อมูลเป็น array เหมือนคีย์อื่น ผ่านเงื่อนไข site_docs_shape เดิมอยู่แล้ว)
alter table public.site_docs drop constraint if exists site_docs_key_check;
alter table public.site_docs add  constraint site_docs_key_check check (key in ('menu','pages','events','settings','campus','fgroups','faculties','majors','programs','people','clubcats','clubs'));

-- 2) ให้ผู้เข้าชมได้รับ clubcats/clubs เฉพาะแถวที่เผยแพร่ (ฟังก์ชันเดิมทั้งหมด เพิ่มเฉพาะ v_cc / v_cl)
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
  v_pp     jsonb;
  v_cc     jsonb;
  v_cl     jsonb;
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

  -- บุคลากรและทีมผู้บริหาร: ไม่มีต้นสังกัด ส่งเฉพาะแถวที่เผยแพร่
  v_pp := public._pub_rows('people', null, null);

  -- ชมรมนักศึกษา: หมวดหมู่และชมรมที่เผยแพร่ (ชมรมไม่ผูกกับสถานะหมวด: ถ้าหมวดถูกซ่อน/ลบ ชมรมจะแสดงในกลุ่ม "ไม่ระบุหมวดหมู่")
  v_cc := public._pub_rows('clubcats', null, null);
  v_cl := public._pub_rows('clubs', null, null);

  return jsonb_build_object('menu', v_menu, 'pages', v_pages, 'events', v_events, 'settings', v_set, 'campus', v_campus,
                            'fgroups', v_fg, 'faculties', v_fa, 'majors', v_mj, 'programs', v_pg,
                            'people', v_pp, 'clubcats', v_cc, 'clubs', v_cl);
end;
$$;
revoke all on function public.get_public_site() from public;
grant execute on function public.get_public_site() to anon, authenticated;

