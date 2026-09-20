/**
 * ECNU 品牌色探测 / probe ECNU's brand colours
 *
 * 目的：从华东师范大学官网取到**真实的**色值，而不是凭印象猜。
 * Purpose: obtain the *actual* colour values from ECNU's site rather than guessing.
 *
 * 两条路子 / two routes:
 *   1. 官网 logo 是 SVG —— 纯文本，可以直接读出 fill / stroke 里的色值。
 *      The site logos are SVG — plain text, so fill/stroke colours are readable directly.
 *   2. 标准色规范页里的示意图是位图，下载到本地供人工查看。
 *      The colour-spec page uses bitmaps; download them for human inspection.
 *
 * 用法 / Usage: node scripts/dev/ecnu-brand-probe.mjs
 */
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const OUT_DIR = path.join(REPO_ROOT, '.tools', 'ecnu-brand');

const BASE = 'https://www.ecnu.edu.cn';

/** 官网引用的 logo（SVG，可读色值）/ logos referenced by the site (SVG, colours readable) */
const SVGS = [
  `${BASE}/images/21/03/19/1yzt3nyx1a/logo3.svg`,
  `${BASE}/images/21/04/13/1fcuv5ewcj/logo.svg`,
  `${BASE}/images/21/03/19/1r916g9urn/logo-bottom.svg`,
];

/** 标准色使用规范页里的示意图（位图，供人工查看）/ the colour-spec bitmaps, for visual review */
const BITMAPS = [
  `${BASE}/__local/B/EC/BF/96043C949003C113E31ED29D130_CB6ED42D_74435.jpg`,
  `${BASE}/__local/8/99/AB/81D5DD88A085D2F39DCCFF7AC06_C4BD458F_83804.jpg`,
  `${BASE}/__local/E/47/74/E6A903ADCFCAEDD9473975F2A83_911BC71B_489F3.jpg`,
  `${BASE}/__local/5/7D/A9/4A8E24CEE6CA80BB43D5815700B_5B3BAD5A_A66E0.jpg`,
  `${BASE}/__local/3/88/8A/D0979C8CEFA02FFC9EED0FFF108_F30557C6_AE17F.jpg`,
];

/** 从 SVG 文本里抽出色值 / pull colour values out of SVG text */
function extractColours(svg) {
  const found = new Map();
  // #rgb / #rrggbb
  for (const match of svg.matchAll(/#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b/g)) {
    const hex = match[1].toUpperCase();
    const normalized = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex;
    if (normalized === 'FFFFFF' || normalized === '000000') continue; // 黑白不算品牌色
    found.set(`#${normalized}`, (found.get(`#${normalized}`) ?? 0) + 1);
  }
  // rgb() / rgba()
  for (const match of svg.matchAll(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/g)) {
    const hex = [match[1], match[2], match[3]]
      .map((n) => Number(n).toString(16).padStart(2, '0').toUpperCase())
      .join('');
    if (hex === 'FFFFFF' || hex === '000000') continue;
    found.set(`#${hex}`, (found.get(`#${hex}`) ?? 0) + 1);
  }
  // 具名颜色里最常见的几个 / a few common named colours
  for (const name of ['crimson', 'darkred', 'maroon', 'firebrick', 'red']) {
    const count = (svg.match(new RegExp(`["':\\s]${name}["';\\s]`, 'g')) ?? []).length;
    if (count > 0) found.set(name, count);
  }
  return [...found.entries()].sort((a, b) => b[1] - a[1]);
}

async function download(url, dest) {
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buffer = Buffer.from(await res.arrayBuffer());
  await writeFile(dest, buffer);
  return buffer.length;
}

async function main() {
  await mkdir(OUT_DIR, { recursive: true });
  console.log(`输出目录 / output dir: ${OUT_DIR}\n`);

  console.log('=== SVG logo 中的色值 / colours found in the logo SVGs ===');
  for (const url of SVGS) {
    const name = path.basename(url);
    try {
      const res = await fetch(url, { redirect: 'follow' });
      if (!res.ok) {
        console.log(`  ${name}: HTTP ${res.status}`);
        continue;
      }
      const svg = await res.text();
      await writeFile(path.join(OUT_DIR, name), svg, 'utf8');
      const colours = extractColours(svg);
      console.log(`  ${name}  (${svg.length} 字节)`);
      if (colours.length === 0) console.log('      （未找到彩色色值，可能是单色 currentColor）');
      for (const [hex, count] of colours.slice(0, 8)) {
        console.log(`      ${hex}  ×${count}`);
      }
    } catch (error) {
      console.log(`  ${name}: FAILED ${error.message}`);
    }
  }

  console.log('\n=== 标准色规范示意图 / colour-spec bitmaps ===');
  BITMAPS.forEach((url, index) => {
    console.log(`  ${String(index + 1).padStart(2)}. ${url}`);
  });
  for (const [index, url] of BITMAPS.entries()) {
    const ext = path.extname(new URL(url).pathname) || '.jpg';
    const dest = path.join(OUT_DIR, `colour-spec-${index + 1}${ext}`);
    try {
      const size = await download(url, dest);
      console.log(`  已下载 / downloaded: colour-spec-${index + 1}${ext}  (${Math.round(size / 1024)} KB)`);
    } catch (error) {
      console.log(`  colour-spec-${index + 1}: FAILED ${error.message}`);
    }
  }
}

await main();
