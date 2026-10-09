import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const directory = new URL('../deploy/pocketbase/pb_migrations/', import.meta.url);
const files = fs.readdirSync(directory).filter(name => name.endsWith('.js')).sort();
assert.ok(files.length > 0, 'Expected production migrations');
const timestamps = new Set();
for (const file of files) {
  const match = /^(\d{10})_[a-z0-9_]+\.js$/.exec(file);
  assert.ok(match, `Invalid migration filename: ${file}`);
  assert.ok(!timestamps.has(match[1]), `Duplicate migration timestamp: ${file}`);
  timestamps.add(match[1]);
  let registrations = 0;
  const context = vm.createContext({ migrate(up, down) {
    assert.equal(typeof up, 'function', `${file}: expected upgrade callback`);
    assert.equal(typeof down, 'function', `${file}: expected rollback callback`);
    registrations++;
  } });
  new vm.Script(fs.readFileSync(new URL(file, directory), 'utf8'), { filename: file })
    .runInContext(context, { timeout: 1000 });
  assert.equal(registrations, 1, `${file}: expected one migration registration`);
}
console.log(`PASS ${files.length} PocketBase migration structures (database execution is separate)`);
