# ลบระบบ Isometric (ระยะที่ 2) ออกจากโค้ดจริง

## ลำดับที่แนะนำ
1. สำรองก่อน (ผมสั่ง git ใน repo ของคุณไม่ได้):

       git checkout -b backup/before-remove-isometric && git push -u origin HEAD
       git checkout -          # กลับ branch เดิมแล้วค่อยแก้

2. `app.js`: วางทับ **เฉพาะเมื่อ** `md5sum app.js` ใน repo ตรงกับ app_1.js ที่คุณส่งมา (ผมทำจากไฟล์นั้น)
   ถ้าไฟล์ใน repo เปลี่ยนไปแล้ว ให้ใช้สคริปต์ลบเฉพาะโค้ด Isometric แทน (ไม่ทับทั้งไฟล์):

       python3 remove_isometric.py app app.js app.js.new && node --check app.js.new && mv app.js.new app.js

   สคริปต์จะหยุดพร้อมแจ้ง ถ้าข้อความที่จะลบไม่ตรงเป๊ะ (ไม่เดา)

3. `style.css`: ไฟล์ที่คุณส่งมามีโค้ด Isometric 0 บรรทัด จึงไม่มีอะไรให้ลบในไฟล์นั้น
   ถ้า style.css ใน repo เคยวาง CSS ของผมไว้ (บล็อก `/* ===== ตัวแก้ไขผัง Isometric` ท้ายไฟล์):

       python3 remove_isometric.py css style.css style.css.new && diff style.css style.css.new && mv style.css.new style.css

4. `scripts/build.mjs`: ถ้ามีบล็อก "คัดลอก assets/" อยู่ ให้ใช้ไฟล์ในแพ็กเกจนี้ (หรือ `python3 remove_isometric.py build ...`)
   ถ้าของจริงของคุณไม่มีบล็อกนี้ ให้คงไว้ตามเดิม ไม่ต้องแก้
5. ลบไฟล์ตาม `REMOVE-FILES.txt`
6. push แล้วดู Build Logs ต้องเห็น `[build] สำเร็จ -> dist/ (index.html, style.css, app.js, config.js)` และไม่มีคำเตือนเรื่อง assets

## ลบอะไรบ้าง (`app.js`: 309,110 -> 279,811 ตัวอักษร ดู `patches/app.js.diff`)
- โมดูล `ce*`/`CE*` ทั้งหมด (บรรทัด 687-844 เดิม): state, ตัวแก้ไข, คลังและการลาก Asset, ย้าย/ปรับขนาด/พลิก/Undo, ตรวจการบันทึกซ้อน, โหลด catalog.json และ sample_layout.json
- route `#/admin/campus/layout` (เรียก ceAdmin), `ceMount()` ใน render(), เงื่อนไข `CE.on` ใน liveRender(), ส่วนหัวและปุ่มเปิดตัวแก้ไขใน campusAdmin()
- `build.mjs`: บล็อกคัดลอก/ตรวจ assets/ และ import `cpSync`

## เก็บไว้ ไม่แตะ
cmView, cmMount, ภาพแผนผัง, หมุดและตัวแก้ไขสถานที่, ค้นหา/กรอง/ซูม/แพน/รายละเอียด, หลังบ้านเดิม, schema.sql, vercel.json, index.html
ข้อมูล Supabase: เอกสาร site_docs 'campus' และ field `items`/`lay` ไม่ถูกลบ (ระบบเดิมส่งผ่านโดยไม่แตะ ทดสอบแล้วใน tests/t6.log)

## ผลทดสอบในเครื่อง (ไม่ใช่ Vercel): tests/t6.log
