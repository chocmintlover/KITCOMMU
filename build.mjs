// Build แบบไม่มีแพ็กเกจเสริม: คัดลอกไฟล์เว็บไป dist/ และสร้าง config.js จาก Environment Variables
// ใช้เฉพาะคีย์สาธารณะ (anon / publishable) เท่านั้น — ห้ามใส่ service_role / secret key
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, rmSync, existsSync, cpSync, statSync, readdirSync } from 'node:fs';
import { resolve, dirname, basename, sep } from 'node:path';
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

// คัดลอก assets/ (Asset ตัวแก้ไขผัง Isometric: assets/campus/*.svg, catalog.json, sample_layout.json) -> dist/assets/
// ต้องครบเสมอ: ไม่มีโฟลเดอร์/ไฟล์ที่ catalog.json อ้างถึงแม้ 1 ไฟล์ -> build ล้ม (ห้ามขึ้นสำเร็จทั้งที่ Asset ไม่ครบ)
const assetsSrc = resolve(root, 'assets');
const assetsDist = resolve(dist, 'assets');
if (!existsSync(assetsSrc)) fail('ไม่พบโฟลเดอร์ assets/ ที่ราก Repository (' + assetsSrc + ')\n  ตัวแก้ไขผัง Isometric ต้องใช้ assets/campus/catalog.json และ SVG — ให้ git add assets/ แล้ว push');
// ไม่คัดลอกไฟล์ที่ขึ้นต้นด้วยจุด (.env, .DS_Store ฯลฯ) และไฟล์คีย์/ความลับ
const isSecretName = (n) => n.startsWith('.') || /\.(env|pem|key|p12|pfx)$/i.test(n) || /^(id_rsa|id_ed25519)/i.test(n) || /^\.?env(\.|$)/i.test(n);
cpSync(assetsSrc, assetsDist, { recursive: true, filter: (src) => src === assetsSrc || !isSecretName(basename(src)) });
const catRel = 'assets/campus/catalog.json';
const catPath = resolve(dist, catRel);
if (!existsSync(catPath)) fail('ไม่พบ ' + catRel + ' ใน dist/ (ตรวจว่ามี assets/campus/catalog.json ใน Repository)');
let cat;
try { cat = JSON.parse(readFileSync(catPath, 'utf8')); } catch (e) { fail(catRel + ' อ่านเป็น JSON ไม่ได้: ' + e.message); }
if (!cat || !Array.isArray(cat.assets) || !cat.assets.length) fail(catRel + ' ไม่มีรายการ assets');
const missing = [];
for (const a of cat.assets) {
  const f = a && a.file;
  const abs = typeof f === 'string' ? resolve(dist, f) : '';
  // path ต้องอยู่ใต้ dist/assets/ เท่านั้น (กัน ../ และ path แปลก)
  if (typeof f !== 'string' || !abs.startsWith(assetsDist + sep)) { missing.push(String(f) + '  (path ไม่ถูกต้อง: ต้องอยู่ใต้ assets/)'); continue; }
  if (!existsSync(abs) || !statSync(abs).isFile() || statSync(abs).size === 0) missing.push(f);
}
for (const f of ['assets/campus/sample_layout.json']) {
  const abs = resolve(dist, f);
  if (!existsSync(abs) || statSync(abs).size === 0) missing.push(f);
}
if (missing.length) fail('Asset ไม่ครบ ขาด/ใช้ไม่ได้ ' + missing.length + ' ไฟล์:\n  ' + missing.join('\n  '));

// ตรวจความปลอดภัย: ห้ามมีไฟล์ .env / คีย์ / ความลับ ใน dist/
const bad = [];
const walk = (d) => { for (const n of readdirSync(d, { withFileTypes: true })) { const p = resolve(d, n.name); if (isSecretName(n.name)) bad.push(p.slice(dist.length + 1)); if (n.isDirectory()) walk(p); } };
walk(dist);
if (bad.length) fail('พบไฟล์ที่ไม่ควรอยู่ใน dist/:\n  ' + bad.join('\n  '));

console.log('[build] สำเร็จ -> dist/ (index.html, style.css, app.js, config.js, assets/ (' + cat.assets.length + ' Asset + catalog.json + sample_layout.json ครบ))');
