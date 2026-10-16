// Build แบบไม่มีแพ็กเกจเสริม: คัดลอกไฟล์เว็บไป dist/ และสร้าง config.js จาก Environment Variables
// ใช้เฉพาะคีย์สาธารณะ (anon / publishable) เท่านั้น — ห้ามใส่ service_role / secret key
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, rmSync, existsSync, cpSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = resolve(root, 'dist');

// โหลด .env / .env.local ตอนรันในเครื่อง (บน Vercel ใช้ Environment Variables ของโปรเจกต์)
for (const f of ['.env', '.env.local']) {
  const p = resolve(root, f);
  if (!existsSync(p)) continue;
  for (const line of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const fail = (msg) => { console.error('\n[build] ผิดพลาด: ' + msg + '\n'); process.exit(1); };

const url = (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
const key = (process.env.SUPABASE_ANON_KEY || '').trim();
if (!url || !key) fail('ไม่พบ SUPABASE_URL หรือ SUPABASE_ANON_KEY (ตั้งใน Vercel > Settings > Environment Variables หรือไฟล์ .env)');
if (!/^https:\/\/[a-z0-9-]+\.supabase\.(co|in)$/i.test(url) && !/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(url))
  fail('SUPABASE_URL รูปแบบไม่ถูกต้อง (ควรเป็น https://<project-ref>.supabase.co)');

// กันใส่คีย์ลับโดยพลาด
if (/^sb_secret_/.test(key)) fail('นี่คือ secret key ห้ามใช้ในฝั่งเว็บ ให้ใช้ anon / publishable key');
if (key.split('.').length === 3) {
  try {
    const role = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString('utf8')).role;
    if (role === 'service_role') fail('นี่คือ service_role key ห้ามใช้ในฝั่งเว็บ ให้ใช้ anon key');
  } catch { fail('SUPABASE_ANON_KEY ไม่ใช่ JWT ที่ถูกต้อง'); }
}

rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
for (const f of ['index.html', 'style.css', 'app.js']) copyFileSync(resolve(root, f), resolve(dist, f));
writeFileSync(
  resolve(dist, 'config.js'),
  'window.KIT_CONFIG=' + JSON.stringify({ supabaseUrl: url, supabaseAnonKey: key }) + ';\n'
);

// คัดลอก assets/ (Asset ตัวแก้ไขผัง Isometric: assets/campus/*.svg, catalog.json, sample_layout.json)
const assetsSrc = resolve(root, 'assets');
let assetNote = '';
if (existsSync(assetsSrc)) {
  cpSync(assetsSrc, resolve(dist, 'assets'), { recursive: true });
  // ตรวจว่า catalog.json และ SVG ที่อ้างถึงมีครบใน dist/ — ไม่ครบให้ build ล้มพร้อมรายชื่อไฟล์ที่ขาด
  const catPath = resolve(dist, 'assets/campus/catalog.json');
  if (!existsSync(catPath)) fail('พบโฟลเดอร์ assets/ แต่ไม่มี assets/campus/catalog.json');
  let cat;
  try { cat = JSON.parse(readFileSync(catPath, 'utf8')); } catch { fail('assets/campus/catalog.json อ่านเป็น JSON ไม่ได้'); }
  const missing = (cat.assets || []).map((a) => a.file).filter((f) => !existsSync(resolve(dist, f)));
  if (missing.length) fail('Asset ที่ catalog.json อ้างถึงแต่ไม่พบไฟล์ (' + missing.length + '):\n  ' + missing.join('\n  '));
  assetNote = ', assets/ (' + (cat.assets || []).length + ' Asset ครบ)';
} else {
  console.warn('[build] คำเตือน: ไม่พบโฟลเดอร์ assets/ — ตัวแก้ไขผัง Isometric จะโหลดคลัง Asset ไม่ได้ (HTTP 404)');
}
console.log('[build] สำเร็จ -> dist/ (index.html, style.css, app.js, config.js' + assetNote + ')');
