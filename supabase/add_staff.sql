-- เพิ่มทีมงาน: สร้างผู้ใช้ก่อนที่ Authentication > Users > Add user (ติ๊ก Auto Confirm) แล้วแก้อีเมลด้านล่าง
insert into public.staff (user_id)
select id from auth.users where email = 'staff@example.com'
on conflict do nothing;

-- ถอดสิทธิ์:
-- delete from public.staff where user_id = (select id from auth.users where email = 'staff@example.com');
