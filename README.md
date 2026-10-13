# KIT — Kosadilok Institute of Technology

เว็บไซต์สถาบัน + ระบบหลังบ้าน (จัดการเมนู หน้าเว็บ หน้าแรก ปฏิทินกิจกรรม ตั้งค่า)
รันบน **Vercel** เก็บข้อมูลบน **Supabase** ล็อกอินทีมงานด้วย Supabase Auth (อีเมล + รหัสผ่าน)

## ไฟล์ในโปรเจกต์
| ไฟล์ | หน้าที่ |
|---|---|
| `index.html`, `style.css`, `app.js` | เว็บไซต์ (ดีไซน์/เมนู/ฟังก์ชันเดิม) |
| `scripts/build.mjs` | Build: สร้าง `dist/` และ `config.js` จาก Environment Variables |
| `supabase/schema.sql` | ตาราง + RLS + ฟังก์ชันอ่านข้อมูลสาธารณะ |
| `supabase/seed.sql` | (ไม่บังคับ) นำเข้าเนื้อหาเดิมจากไฟล์ HTML ที่แนบมา |
| `supabase/add_staff.sql` | เพิ่มอีเมลทีมงานที่มีสิทธิ์แก้ไข |
| `.env.example`, `vercel.json` | ตัวอย่างค่าตั้งต้น / ตั้งค่า Vercel |

## ขั้นตอนติดตั้ง
1. **Supabase**: สร้างโปรเจกต์ → SQL Editor → รัน `supabase/schema.sql` → (ถ้าต้องการเนื้อหาเดิม) รัน `supabase/seed.sql`
2. **Auth**: Authentication → Sign In / Providers → Email: **ปิด "Allow new users to sign up"**
3. **สร้างบัญชีทีมงาน**: Authentication → Users → Add user (ใส่อีเมล+รหัสผ่าน, ติ๊ก Auto Confirm) → แก้อีเมลใน `supabase/add_staff.sql` แล้วรัน
4. **GitHub**: อัปโหลดโฟลเดอร์นี้เป็น repository
5. **Vercel**: Import repository (Framework: Other) → ใส่ Environment Variables:
   - `SUPABASE_URL` = Project URL
   - `SUPABASE_ANON_KEY` = anon / publishable key (**ห้ามใช้ service_role**)
   → Deploy
6. เปิดเว็บ → ไอคอนกุญแจมุมขวาบน (`#/admin`) → ล็อกอินด้วยบัญชีทีมงาน

## วิธีทำงานของสิทธิ์
- ผู้เข้าชมอ่านได้เฉพาะ **สิ่งที่เผยแพร่แล้ว** ผ่านฟังก์ชัน `get_public_site()` (ฉบับร่าง/เมนูที่ซ่อนไม่ถูกส่งออก) และเข้าตารางตรง ๆ ไม่ได้
- เขียน/ลบ/อ่านข้อมูลทั้งหมดได้เฉพาะผู้ล็อกอินที่อยู่ในตาราง `staff` (บังคับด้วย RLS ที่ฐานข้อมูล ไม่ใช่แค่หน้าเว็บ)
- สถานะ "เผยแพร่" มีผลกับผู้เข้าชมทันที ไม่ต้องกดเผยแพร่แยก
- คีย์ที่อยู่ในหน้าเว็บคือ anon เท่านั้น; `build.mjs` จะหยุดทันทีหากพบ service_role / secret key

## รันในเครื่อง
```bash
cp .env.example .env   # กรอกค่า
node scripts/build.mjs # สร้าง dist/
npx serve dist         # หรือเซิร์ฟเวอร์ static ใดก็ได้
```
