/* ตัวจำลอง Supabase ในหน่วยความจำ (เก็บใน localStorage ของเบราว์เซอร์ทดสอบ) ใช้ทดสอบเท่านั้น */
(function(){
const K='mock_site_docs',S=()=>JSON.parse(localStorage.getItem(K)||'{}'),W=o=>localStorage.setItem(K,JSON.stringify(o));
const pub=(a,pf,ids)=>(Array.isArray(a)?a:[]).filter(r=>r.status==='published'&&(!pf||ids.includes(r[pf])));
function getPublic(){const d=S();const g=pub(d.fgroups),f=pub(d.faculties,'groupId',g.map(x=>x.id)),m=pub(d.majors,'facultyId',f.map(x=>x.id)),p=pub(d.programs,'majorId',m.map(x=>x.id));
 return {menu:d.menu||[],pages:pub(d.pages),events:pub(d.events),settings:d.settings||{},campus:d.campus||{},fgroups:g,faculties:f,majors:m,programs:p}}
const chan={on(){return chan},subscribe(){return chan}};
window.supabase={createClient(){return {
 rpc:async(n)=>n==='get_public_site'?{data:getPublic(),error:null}:n==='is_staff'?{data:!!localStorage.getItem('mock_staff'),error:null}:{data:null,error:{message:'unknown rpc'}},
 from:()=>({select:async()=>({data:Object.entries(S()).map(([key,data])=>({key,data})),error:null}),
   upsert:async(r)=>{if(window.__failSave)return {error:{message:'mock fail'}};const d=S();d[r.key]=r.data;W(d);return {error:null}}}),
 auth:{getSession:async()=>({data:{session:localStorage.getItem('mock_staff')?{user:{email:'staff@example.com'}}:null}}),signInWithPassword:async()=>({error:null}),signOut:async()=>({})},
 channel:()=>chan,
 storage:{from:()=>({upload:async()=>({error:null}),getPublicUrl:()=>({data:{publicUrl:''}}),list:async()=>({data:[],error:null})})}}}};
})();
