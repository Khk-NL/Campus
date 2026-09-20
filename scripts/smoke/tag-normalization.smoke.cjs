/**
 * 标签归一化的冒烟测试 / smoke test for tag normalisation
 *
 * 这组断言存在的理由很具体：参考项目因为标签口径分裂而**静默丢失条目**，
 * 而"静默"意味着没有报错、没有日志、只是条目不见了。因此每一类分裂都必须有一条断言钉住。
 *
 * These assertions exist for a concrete reason: the reference project silently loses entries to
 * tag key splitting, and "silently" means no error, no log — the entries are simply gone. Every
 * class of split therefore gets its own assertion.
 *
 * 用法 / Usage: node scripts/smoke/tag-normalization.smoke.cjs
 */
const assert = require('node:assert/strict');

const models = require('../../packages/models/dist/index.js');

let passed = 0;
function check(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok  ${name}`);
}

function main() {
  console.log('tag normalisation smoke test / 标签归一化冒烟测试');

  // -------------------------------------------------------------------------
  // 归一化的四类分裂 / the four classes of split
  // -------------------------------------------------------------------------
  check('首尾空白不产生新标签', () => {
    assert.equal(models.normalizeTagName('  羽毛球 '), models.normalizeTagName('羽毛球'));
    assert.equal(models.normalizeTagName('\t羽毛球\n'), models.normalizeTagName('羽毛球'));
  });

  check('全角与半角不产生新标签（NFKC，对中文最关键）', () => {
    // U+3000 全角空格 与 U+0020 半角空格；全角字母与半角字母。
    assert.equal(models.normalizeTagName('羽毛球\u3000'), models.normalizeTagName('羽毛球'));
    assert.equal(models.normalizeTagName('ｂａｄｍｉｎｔｏｎ'), models.normalizeTagName('badminton'));
    assert.equal(
      models.normalizeTagName('课程\u3000评价'),
      models.normalizeTagName('课程 评价'),
    );
  });

  check('大小写不产生新标签', () => {
    assert.equal(models.normalizeTagName('Badminton'), models.normalizeTagName('badminton'));
    assert.equal(models.normalizeTagName('CS'), models.normalizeTagName('cs'));
  });

  check('内部连续空白折叠，不产生新标签', () => {
    assert.equal(models.normalizeTagName('课程   评价'), models.normalizeTagName('课程 评价'));
  });

  check('空串与纯空白归一化为空串（调用方据此判定 unknown）', () => {
    assert.equal(models.normalizeTagName(''), '');
    assert.equal(models.normalizeTagName('   '), '');
  });

  // -------------------------------------------------------------------------
  // 解析 / resolution
  // -------------------------------------------------------------------------
  const badminton = {
    id: 't1',
    name: '羽毛球',
    normalizedName: models.normalizeTagName('羽毛球'),
    status: 'active',
  };
  const oldBadminton = {
    id: 't0',
    name: '羽球',
    normalizedName: models.normalizeTagName('羽球'),
    status: 'merged',
    mergedIntoId: 't1',
  };
  const tags = [badminton, oldBadminton];
  const aliases = [{ normalizedAlias: models.normalizeTagName('badminton'), tagId: 't1' }];

  check('规范名直接命中', () => {
    const result = models.resolveTag('羽毛球', tags, aliases);
    assert.equal(result.kind, 'canonical');
    assert.equal(result.tag.id, 't1');
  });

  check('写法变体（全角/大小写）仍命中同一个规范标签', () => {
    for (const raw of [' ｂａｄｍｉｎｔｏｎ ', 'BADMINTON', 'Badminton']) {
      const result = models.resolveTag(raw, tags, aliases);
      assert.equal(result.kind, 'alias', `"${raw}" 应通过别名命中`);
      assert.equal(result.tag.id, 't1');
    }
  });

  check('归并标签跟随到存活的那一个，而不是自成一类', () => {
    const result = models.resolveTag('羽球', tags, aliases);
    assert.equal(result.kind, 'merged');
    assert.equal(result.tag.id, 't1');
    assert.equal(result.via.id, 't0');
  });

  check('词表里没有的词返回 unknown，而不是自动创建', () => {
    const result = models.resolveTag('冬季长跑', tags, aliases);
    assert.equal(result.kind, 'unknown');
    assert.equal(result.normalizedName, models.normalizeTagName('冬季长跑'));
  });

  check('空标签返回 unknown 而不是命中第一个标签', () => {
    assert.equal(models.resolveTag('', tags, aliases).kind, 'unknown');
  });

  check('归并链有环时不会死循环', () => {
    const a = { id: 'a', name: 'A', normalizedName: 'a', status: 'merged', mergedIntoId: 'b' };
    const b = { id: 'b', name: 'B', normalizedName: 'b', status: 'merged', mergedIntoId: 'a' };
    const result = models.resolveTag('a', [a, b], []);
    assert.ok(result.kind === 'merged', '应返回 merged 而不是抛错或挂死');
    assert.ok(result.tag.id === 'a' || result.tag.id === 'b');
  });

  // -------------------------------------------------------------------------
  // 分组：这是"阻止分裂"最直接的体现 / grouping is the most direct anti-split tool
  // -------------------------------------------------------------------------
  check('同一个概念的多种写法被归到同一组', () => {
    const groups = models.groupEquivalentTagNames([
      '羽毛球',
      ' 羽毛球 ',
      'Badminton',
      'ｂａｄｍｉｎｔｏｎ',
      '篮球',
    ]);
    // 注意：'Badminton' 与 '羽毛球' 是**不同**的概念（一个中文名一个英文名），
    // 归一化不会也不该把它们合并 —— 合并要靠别名表。
    // 'Badminton' and '羽毛球' are different strings; merging those requires an alias entry,
    // which is exactly why the alias table exists.
    assert.equal(groups.size, 3, '应为：羽毛球 / badminton / 篮球 三组');
    assert.deepEqual(groups.get(models.normalizeTagName('羽毛球')), ['羽毛球', ' 羽毛球 ']);
    assert.deepEqual(groups.get(models.normalizeTagName('badminton')), [
      'Badminton',
      'ｂａｄｍｉｎｔｏｎ',
    ]);
  });

  check('分组会丢弃空标签', () => {
    assert.equal(models.groupEquivalentTagNames(['', '   ', '羽毛球']).size, 1);
  });

  console.log(`\n${passed} checks passed / 全部通过`);
}

try {
  main();
} catch (err) {
  console.error('\nSMOKE TEST FAILED / 冒烟测试失败');
  console.error(err);
  process.exitCode = 1;
}
