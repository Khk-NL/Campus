/**
 * 标签归一化（§27.9 / CAMPUS_APP_SCHEMA_DESIGN.md §4）
 *
 * 这是全项目最容易被低估的一处。参考项目已经因为标签口径分裂而**静默丢失条目**：
 * 它用大小写敏感的 `trim()` 去重、没有别名、没有受控词表，且分类与标签混在同一字段里，
 * 导致同一个概念出现三套匹配口径。其源码注释明确记录了"存外部大小写会让仓库从分类结果里
 * 消失"。
 *
 * This is the most under-estimated part of the project. The reference implementation already
 * loses entries silently because its tag keys split: case-sensitive `trim()` dedupe, no aliases,
 * no controlled vocabulary, and categories and tags mixed into one field. Its own source comment
 * records that storing an external label's casing makes repositories vanish from category results.
 *
 * 因此归一化必须与标签功能**一起交付**，而且必须是**纯函数**（可单测、可跨端复用）。
 * Normalisation ships *with* the tag feature and is a pure function so it can be unit tested and
 * shared across platforms.
 */

/**
 * NFKC 是关键的一步，对中文尤其如此：它把全角字符折成半角，于是
 * 「羽毛球」与「羽毛球」（全角空格 / 全角字母混排）会归到同一个键。
 * 没有这一步，中文标签会以肉眼难辨的方式分裂。
 *
 * NFKC is the critical step, especially for Chinese: it folds full-width characters to
 * half-width, so the same name written with full-width spacing or letters collapses to one key.
 * Without it, Chinese tags split in ways that are nearly invisible to the eye.
 */
export function normalizeTagName(raw: string): string {
  return (
    raw
      // 1. 去掉首尾空白（含全角空格，NFKC 之后 U+3000 会变成 U+0020）
      .trim()
      // 2. NFKC：全角 → 半角、兼容字符归一
      .normalize('NFKC')
      // 3. 内部连续空白折成一个半角空格
      .replace(/\s+/g, ' ')
      // 4. 小写（对中文无影响，对英文与缩写是必须的）
      .toLowerCase()
  );
}

/** 标签的生命周期；归并而不是删除，保留可追溯性 / merge rather than delete, to stay traceable */
export type TagStatus = 'active' | 'merged' | 'deprecated';

export interface TagRecord {
  readonly id: string;
  /** 规范名，用于展示 / the canonical display name */
  readonly name: string;
  /** 归一化后的键，唯一索引落在它上面 / the normalised key the unique index sits on */
  readonly normalizedName: string;
  readonly status: TagStatus;
  /** `status === 'merged'` 时指向被并入的标签 / the surviving tag when merged */
  readonly mergedIntoId?: string;
}

/** 别名表：把"另一种写法"指向主标签 / alias table pointing alternative spellings at a tag */
export interface TagAliasRecord {
  readonly normalizedAlias: string;
  readonly tagId: string;
}

/**
 * 一次标签解析的结果。
 *
 * `unknown` 是**一等结果**而不是错误：它表示"这个词表里没有"，需要进入待审队列
 * （§27.9：受控词表 + 允许提交新标签待审）。把它做成异常会让调用方倾向于"先建了再说"，
 * 而那正是词表失控的起点。
 *
 * `unknown` is a first-class outcome rather than an error: it means "not in the vocabulary" and
 * belongs in the review queue. Making it an exception would push callers to "just create it",
 * which is exactly how a controlled vocabulary loses control.
 */
export type TagResolution =
  | { readonly kind: 'canonical'; readonly tag: TagRecord }
  | { readonly kind: 'alias'; readonly tag: TagRecord; readonly via: string }
  | { readonly kind: 'merged'; readonly tag: TagRecord; readonly via: TagRecord }
  | { readonly kind: 'unknown'; readonly normalizedName: string };

/** 跟随归并链到最终存活的标签，并防止环形归并 / follow merges, guarding against cycles */
function followMerges(
  start: TagRecord,
  byId: ReadonlyMap<string, TagRecord>,
): TagRecord {
  let current = start;
  const seen = new Set<string>([current.id]);
  while (current.status === 'merged' && current.mergedIntoId) {
    const next = byId.get(current.mergedIntoId);
    if (!next || seen.has(next.id)) break;
    seen.add(next.id);
    current = next;
  }
  return current;
}

/**
 * 把一个原始标签名解析成词表里的规范标签。
 *
 * 顺序刻意是"**先算归一化键，再查词表，最后查别名**"：
 * 反过来（先查别名再归一化）会让"别名的大小写变体"漏掉，这类漏洞在词表变大后极难排查。
 *
 * The order is deliberately "normalise first, then look up the table, then aliases": reversing it
 * would let case variants of an alias slip through, and such holes become very hard to find once
 * the vocabulary grows.
 */
export function resolveTag(
  raw: string,
  tags: readonly TagRecord[],
  aliases: readonly TagAliasRecord[] = [],
): TagResolution {
  const key = normalizeTagName(raw);
  if (!key) return { kind: 'unknown', normalizedName: key };

  const byId = new Map(tags.map((tag) => [tag.id, tag] as const));
  const byNormalized = new Map(tags.map((tag) => [tag.normalizedName, tag] as const));

  const direct = byNormalized.get(key);
  if (direct) {
    const finalTag = followMerges(direct, byId);
    if (finalTag.id !== direct.id) {
      return { kind: 'merged', tag: finalTag, via: direct };
    }
    return { kind: 'canonical', tag: finalTag };
  }

  const alias = aliases.find((entry) => entry.normalizedAlias === key);
  if (alias) {
    const target = byId.get(alias.tagId);
    if (target) {
      return { kind: 'alias', tag: followMerges(target, byId), via: alias.normalizedAlias };
    }
  }

  return { kind: 'unknown', normalizedName: key };
}

/**
 * 把一批原始标签名按归一化键分组。
 *
 * 用途：运营在后台看到"这次提交引入了哪些新标签"时，能一眼看出"
 * `羽毛球`、`羽球`、`Badminton` 其实是同一个概念"，而不是逐个手工比对。
 * 返回的键是归一化键，值是该组里出现过的所有原始写法。
 *
 * Groups raw tag names by their normalised key, so an operator reviewing a submission can see at
 * a glance that three spellings are one concept instead of comparing them by hand.
 */
export function groupEquivalentTagNames(
  raws: readonly string[],
): ReadonlyMap<string, readonly string[]> {
  const groups = new Map<string, string[]>();
  for (const raw of raws) {
    const key = normalizeTagName(raw);
    if (!key) continue;
    const bucket = groups.get(key);
    if (bucket) {
      // 保留原始写法以便展示，但去重（同一个写法重复出现没有信息量）。
      // Keep the original spelling for display, but deduplicate: a repeated spelling carries
      // no information.
      if (!bucket.includes(raw)) bucket.push(raw);
    } else {
      groups.set(key, [raw]);
    }
  }
  return groups;
}
