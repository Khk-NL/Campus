import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = new URL('../', import.meta.url);
const forbidden = /没有|不是|不能|无法|不支持|尚未|未配置|未接入|暂无|不代表|不会/;

test('Chinese UI labels use direct wording', () => {
  const copy = JSON.parse(fs.readFileSync(new URL('apps/mobile/lib/l10n/app_zh.arb', root), 'utf8'));
  for (const [key, value] of Object.entries(copy)) {
    if (!key.startsWith('@') && typeof value === 'string') assert.ok(!forbidden.test(value), key);
  }
});

test('feature strings omit negative explanatory copy', () => {
  const directory = new URL('apps/mobile/lib/features/', root);
  for (const entry of fs.readdirSync(directory, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.dart')) continue;
    const file = path.join(entry.parentPath, entry.name);
    const source = fs.readFileSync(file, 'utf8').split(/\r?\n/)
      .filter(line => !line.trimStart().startsWith('//')).join('\n');
    assert.ok(!forbidden.test(source), path.relative(new URL('.', root).pathname, file));
  }
});

test('public website copy retains identity and privacy information with direct wording', () => {
  const directory = new URL('deploy/pocketbase/pb_public/', root);
  for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.html'))) {
    const html = fs.readFileSync(new URL(name, directory), 'utf8');
    assert.ok(!forbidden.test(html), name);
  }
  const privacy = fs.readFileSync(new URL('privacy.html', directory), 'utf8');
  assert.ok(privacy.includes('独立运营'));
  assert.ok(privacy.includes('数据库管理员'));
  assert.ok(privacy.includes('发送给 ChatECNU'));
});
