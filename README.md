# KIT Campus Assets — ระยะที่ 1
- assets/campus/*.svg  : 25 Asset (พื้นหลังโปร่งใส) | catalog.json : id, ชื่อ, หมวด, ขนาดภาพ, จุดยึด (ax,ay), footprint (fw,fd), layer, linkable
- sample_layout.json   : ผังตัวอย่าง 84 ชิ้น (พิกัดโลก x,y = จุดยึดของ Asset; เรียงซ้อนตาม layer → z → y)
- sample_layout.svg/png: ภาพที่ประกอบจากผังตัวอย่าง | assets_sheet.png : ภาพรวมคลัง
- tools/ : สคริปต์ Python สร้าง Asset (python3 gen.py แล้ว python3 layout.py) — ไม่ต้องนำขึ้นเว็บ
ยังไม่ได้แก้ app.js / style.css / schema.sql
