#!/usr/bin/env python3
"""ลบระบบตัวแก้ไขผัง Isometric (ระยะที่ 2) ออกจาก app.js / style.css / build.mjs
ใช้: python3 remove_isometric.py app <in> <out> | css <in> <out> | build <in> <out>
ทุกขั้นตรวจว่าข้อความที่จะลบ 'ตรงเป๊ะและพบครั้งเดียว' ไม่งั้นหยุดพร้อมแจ้ง (ไม่คาดเดา)"""
import re,sys
def die(m): print('ERROR:',m); sys.exit(1)
def once(s,old,new,label):
    n=s.count(old)
    if n!=1: die(f'{label}: พบ {n} ครั้ง (ต้องพบ 1) — ไฟล์นี้ต่างจากที่คาด ไม่แก้ต่อ')
    return s.replace(old,new)
def app(s):
    a=s.find("/* ===== ตัวแก้ไขผัง Isometric (ลากวาง)")
    b=s.find("/* ===== Admin: จัดการแผนผังสถาบัน ===== */")
    if a<0 or b<0 or b<a or s.count("/* ===== ตัวแก้ไขผัง Isometric (ลากวาง)")!=1: die('ไม่พบขอบเขตโมดูล ce* ชัดเจน')
    blk=s[a:b]
    # โมดูลต้องมีแต่โค้ด ce*/CE* เท่านั้น: ทุกบรรทัดระดับบนสุดต้องขึ้นต้นด้วย const ce/CE, function ce, async function ce, คอมเมนต์ หรือเป็นบรรทัดต่อเนื่อง
    for i,l in enumerate(blk.split('\n')):
        if re.match(r'^(const|let|var|function|async function|class)\b',l) and not re.match(r'^(const (ce|CE)|function ce|async function ce)',l):
            die(f'พบโค้ดระดับบนสุดที่ไม่ใช่ ce* ในโมดูล (บรรทัดที่ {i+1}): {l[:80]}')
    s=s[:a]+s[b:]
    s=once(s,"if(CE.on&&$('ce-view')){ceRemote();return}","","liveRender guard")
    s=once(s,"else if(sec==='campus'&&parts[1]==='layout')main=ceAdmin();","","router layout")
    s=once(s,"cmMount();ceMount();","cmMount();","render() ceMount")
    s,n=re.subn(r'<h2>ตัวแก้ไขผัง Isometric \(ลากวาง\)</h2>.*?เปิดตัวแก้ไขผัง Isometric</a></p>\n','',s,flags=re.S)
    if n!=1: die(f'campusAdmin block: พบ {n} (ต้อง 1)')
    return s
def css(s):
    m="/* ===== ตัวแก้ไขผัง Isometric"
    if s.count(m)!=1: 
        print('ไม่พบบล็อก CSS Isometric (หรือพบมากกว่า 1) — ไม่มีอะไรต้องลบ' if s.count(m)==0 else 'พบหลายบล็อก ตรวจเอง'); 
        if s.count(m)!=0: sys.exit(1)
        return s
    i=s.index(m); head=s[:i].rstrip('\n')+'\n'; tail=s[i:]
    nxt=re.search(r'\n/\* =====',tail[len(m):])
    if nxt: print('คำเตือน: มีส่วน CSS อื่นต่อท้ายบล็อก Isometric — ลบเฉพาะถึงก่อนส่วนถัดไป ตรวจ diff'); rest=tail[len(m)+nxt.start():]; return head+rest.lstrip('\n') if False else head+'\n'+rest.lstrip('\n')
    return head
def build(s):
    a=s.find("// คัดลอก assets/ (Asset ตัวแก้ไขผัง"); b=s.find("console.log('[build] สำเร็จ")
    if a<0 or b<a: die('ไม่พบบล็อก assets ใน build')
    s=s[:a]+"console.log('[build] สำเร็จ -> dist/ (index.html, style.css, app.js, config.js)');\n"
    s=s.replace("rmSync, existsSync, cpSync }","rmSync, existsSync }")
    return s
if __name__=='__main__':
    if len(sys.argv)!=4 or sys.argv[1] not in ('app','css','build'): die(__doc__)
    t=open(sys.argv[2],encoding='utf-8').read()
    o={'app':app,'css':css,'build':build}[sys.argv[1]](t)
    open(sys.argv[3],'w',encoding='utf-8',newline='').write(o); print('OK',sys.argv[1],len(t),'->',len(o))
