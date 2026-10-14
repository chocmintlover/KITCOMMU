import json
exec(open('run_tests.py',encoding='utf-8').read().split("R=[]")[0])
from playwright.sync_api import sync_playwright
ok=[]
def chk(n,c,i=''): ok.append(bool(c)); print('PASS' if c else 'FAIL',n,i)
with sync_playwright() as pw:
    b=pw.chromium.launch()
    c=b.new_context(viewport={'width':1280,'height':900})
    c.route("**/cdn.jsdelivr.net/**",lambda r:r.fulfill(body=mock,content_type='application/javascript'))
    c.route("**/fonts.*/**",lambda r:r.abort())
    c.add_init_script("if(!localStorage.getItem('mock_site_docs'))localStorage.setItem('mock_site_docs',%s);localStorage.setItem('mock_staff','1');"%json.dumps(json.dumps(seed)))
    pg=c.new_page(); errs=[]; pg.on('pageerror',lambda e:errs.append(str(e)))
    st=lambda i:next((p for p in json.loads(pg.evaluate("localStorage.getItem('mock_site_docs')"))['programs'] if p['id']==i),None)
    # ไปที่รายการหลักสูตรแล้วคลิกตามเส้นทางที่ผู้ใช้จริงใช้
    pg.goto(BASE+'#/admin/programs'); pg.reload(); pg.wait_for_selector('h1',timeout=8000)
    body=pg.inner_text('body'); chk('รายการหลักสูตรหลังบ้านแสดงสถานะค่าเล่าเรียนทุกแถว','ค่าเล่าเรียน 25,000 บาท/ภาคการศึกษา' in body and 'ยังไม่ระบุค่าเล่าเรียน' in body)
    pg.screenshot(path='/home/claude/kit/adm_list.png')
    # คลิกแก้ไขหลักสูตร C (ยังไม่ระบุ)
    row=pg.locator("li,tr,.card,div").filter(has_text='หลักสูตร C (ไม่มีข้อมูล)').last
    links=pg.locator("a[href*='/admin/programs/edit/pg_c']"); chk('มีลิงก์แก้ไขหลักสูตร C ในรายการ',links.count()>=1,str(links.count()))
    links.first.click(); pg.wait_for_selector('#f_tuition',timeout=5000)
    chk('คลิกแก้ไขจากรายการ -> เจอช่องค่าเล่าเรียน (ว่างเพราะยังไม่เคยระบุ)',pg.input_value('#f_tuition')=='')
    pg.fill('#f_tuition','31500'); pg.click("button:has-text('บันทึก')"); pg.wait_for_timeout(500)
    chk('แก้ไขหลักสูตรเดิมแล้วบันทึกลงฐานข้อมูล',st('pg_c').get('tuition')==31500,repr(st('pg_c').get('tuition')))
    # กลับรายการ -> เปิดซ้ำ -> ค่าเดิมกลับมา
    pg.click("a:has-text('กลับรายการ')"); pg.wait_for_selector('h1')
    chk('รายการอัปเดตเป็น 31,500','ค่าเล่าเรียน 31,500 บาท/ภาคการศึกษา' in pg.inner_text('body'))
    pg.locator("a[href*='/admin/programs/edit/pg_c']").first.click(); pg.wait_for_selector('#f_tuition')
    chk('เปิดแก้ไขซ้ำ -> แสดงค่าเดิม 31500',pg.input_value('#f_tuition')=='31500')
    # เพิ่มหลักสูตรใหม่ผ่านปุ่มเพิ่มในรายการ
    pg.goto(BASE+'#/admin/programs'); pg.wait_for_selector('h1')
    add=pg.locator("a[href*='/admin/programs/edit/new']"); chk('มีปุ่มเพิ่มหลักสูตร',add.count()>=1)
    add.first.click(); pg.wait_for_selector('#f_tuition',timeout=5000)
    chk('หน้าเพิ่มหลักสูตรมีช่องค่าเล่าเรียน และว่างโดยปริยาย',pg.input_value('#f_tuition')=='')
    pg.select_option('#f_majorId','mj2'); pg.fill('#f_nameTh','หลักสูตรเพิ่มใหม่ไม่ระบุค่าเล่าเรียน'); pg.select_option('#f_status','published')
    pg.click("button:has-text('บันทึก')"); pg.wait_for_timeout(500)
    n=[p for p in json.loads(pg.evaluate("localStorage.getItem('mock_site_docs')"))['programs'] if p['nameTh']=='หลักสูตรเพิ่มใหม่ไม่ระบุค่าเล่าเรียน']
    chk('เพิ่มหลักสูตรใหม่โดยเว้นค่าเล่าเรียนได้',len(n)==1 and n[0].get('tuition')=='',repr(n and n[0].get('tuition')))
    pid=n[0]['id']
    pg.goto(BASE+'#/admin/programs/edit/'+pid); pg.reload(); pg.wait_for_selector('#f_tuition'); pg.fill('#f_tuition','0'); pg.click("button:has-text('บันทึก')"); pg.wait_for_timeout(500)
    chk('ใส่ 0 แล้วบันทึกได้',st(pid).get('tuition')==0 and st(pid).get('tuition')!='')
    # หน้าสาธารณะ (ไม่ล็อกอิน) ใช้ฐานข้อมูลเดียวกันผ่านตัวคัดกรอง get_public_site
    db=pg.evaluate("localStorage.getItem('mock_site_docs')"); c.close()
    c2=b.new_context(viewport={'width':390,'height':800}); c2.route("**/cdn.jsdelivr.net/**",lambda r:r.fulfill(body=mock,content_type='application/javascript')); c2.route("**/fonts.*/**",lambda r:r.abort())
    c2.add_init_script("localStorage.setItem('mock_site_docs',%s)"%json.dumps(db))
    p2=c2.new_page()
    for i,exp in (('pg_c','ค่าเล่าเรียน 31,500 บาท/ภาคการศึกษา'),(pid,'ค่าเล่าเรียน 0 บาท/ภาคการศึกษา'),('pg_b','ค่าเล่าเรียน 0 บาท/ภาคการศึกษา')):
        p2.goto(BASE+'#/program/'+i); p2.reload(); p2.wait_for_selector('.fqph'); chk('หน้าสาธารณะ '+i,exp in ' '.join(p2.inner_text('.fqph').split()))
    b.close()
chk('ไม่มี JS error',not errs,'; '.join(errs)[:200]); print('สรุป %d/%d'%(sum(ok),len(ok)))
