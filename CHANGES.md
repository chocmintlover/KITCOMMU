# ระยะที่ 2 — ตัวแก้ไขผัง Isometric (ลากวาง)

## ไฟล์ที่เปลี่ยน
- app.js  (+160 บรรทัด, เพิ่มโมดูล `ce*` ก่อนส่วน "Admin: จัดการแผนผังสถาบัน" + แก้ 4 จุดเล็ก)
  1. router: เพิ่ม `#/admin/campus/layout` → `ceAdmin()`
  2. render(): เพิ่ม `ceMount()` หลัง `cmMount()`
  3. liveRender(): ถ้าเปิดตัวแก้ไขอยู่ ไม่ re-render ทับงาน แต่แจ้งเตือนเมื่อมีผู้อื่นแก้ผัง
  4. campusAdmin(): เพิ่มปุ่มเปิดตัวแก้ไข
- style.css: เพิ่มคลาส `.ce-*` / `.cedt` ท้ายไฟล์ (ตรวจแล้วไม่ชนคลาสเดิม)
- assets/campus/: Asset SVG 25 ชิ้น + catalog.json + sample_layout.json  (วางไว้ข้าง index.html)

ไม่แตะ: schema.sql, cmView() และโค้ดภาพ/หมุด/สถานที่เดิม

## วิธีติดตั้ง
1. วาง app.js, style.css ทับของเดิม และวางโฟลเดอร์ assets/ ไว้ระดับเดียวกับ index.html
2. ตรวจว่า build ของ Vercel คัดลอกโฟลเดอร์ assets/ ขึ้นไปด้วย (ถ้า build.mjs คัดลอกเฉพาะไฟล์ที่ระบุ ต้องเพิ่ม assets/)
3. เปิด #/admin/campus → "เปิดตัวแก้ไขผัง Isometric"

## ข้อมูล
site_docs key 'campus' เพิ่ม 2 field: `items` (รายการวาง) และ `lay` (ขนาด/สีพื้น/จุดกำเนิดพิกัด) — field เดิมไม่ถูกแตะ
item = {id, a(assetId), x, y, s, r, z, fx, ...} · ลำดับซ้อน = layer(catalog) → z → y
บันทึก: กดปุ่ม "บันทึก" เท่านั้น → อ่านเอกสารล่าสุด, รวมเฉพาะ items/lay, เขียนแบบมีเงื่อนไข updated_at (กันทับ)
