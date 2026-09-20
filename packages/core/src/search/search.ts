/**
 * 统一搜索（文档 §11）
 *
 * §11 明确第一阶段**不做复杂语义搜索**，优先实现：标题搜索、标签搜索、分类搜索、
 * 最近使用排序。本文件实现前三者，并给出**确定性的排序**："最近使用"由调用方在此之上
 * 叠加（它需要真实的使用记录）。
 *
 * §11 explicitly rules out complex semantic search in the first stage and asks for title,
 * tag and category search plus recency ordering. This file implements the first three with
 * **deterministic ranking**; recency is layered on top by the caller, which has the actual
 * usage data.
 */
import type { SearchDocument, SearchableKind } from './documents';

/** 匹配发生在哪个字段上 / which field produced the match */
export type MatchField = 'title' | 'tag' | 'category' | 'keyword';

/**
 * 命中权重。
 *
 * 排序刻意做成"可解释"的：分数完全由 `MatchField` 决定，而不是某种不透明的相似度。
 * 这样当用户觉得结果不合理时，我们能看到究竟是标题匹配错了还是标签匹配过度，而不是
 * 面对一个无法调试的数字。
 *
 * Ranking is deliberately explainable: the score comes from the `MatchField` alone, never
 * from an opaque similarity value. When results look wrong we can see whether the title or a
 * tag caused it, instead of staring at an undebuggable number.
 */
const FIELD_WEIGHT: Readonly<Record<MatchField, number>> = {
  title: 100,
  tag: 60,
  keyword: 30,
  category: 20,
};

export interface SearchQuery {
  /** 原始查询串；空串表示不过滤 / the raw query; an empty string means no filtering */
  readonly text: string;
  /** 限定类别 / restrict to these kinds */
  readonly kinds?: readonly SearchableKind[];
  /** 返回上限 / maximum hits to return */
  readonly limit?: number;
}

export interface SearchHit {
  readonly document: SearchDocument;
  readonly score: number;
  readonly matchedOn: MatchField;
  /** 命中的具体文本，便于 UI 高亮 / the matched text, for UI highlighting */
  readonly matchedText: string;
}

/** 归一化：小写 + 去首尾空白。中文不受影响，英文大小写不敏感。 */
function normalize(value: string): string {
  return value.trim().toLowerCase();
}

/**
 * 为单个文档打分。返回 null 表示不匹配。
 *
 * 匹配规则是**子串**而非分词：中文没有空格分词，引入分词器会带来远超 Phase 0 需要的
 * 复杂度，而子串匹配对"羽毛球""图书馆"这类查询已经够用。
 *
 * Substring matching rather than tokenisation: Chinese has no word separators, and adding a
 * tokeniser would cost far more than Phase 0 needs. Substring matching already handles
 * queries like "羽毛球" or "图书馆" well.
 */
function scoreDocument(document: SearchDocument, needle: string): SearchHit | null {
  let best: SearchHit | null = null;

  const consider = (field: MatchField, value: string): void => {
    if (!value) return;
    const haystack = normalize(value);
    if (!haystack.includes(needle)) return;

    // 同一字段内，完全相等比子串更相关；前缀又比中缀更相关。
    // Within one field, an exact match beats a substring, and a prefix beats an infix.
    const bonus = haystack === needle ? 20 : haystack.startsWith(needle) ? 10 : 0;
    const score = FIELD_WEIGHT[field] + bonus;

    if (!best || score > best.score) {
      best = { document, score, matchedOn: field, matchedText: value };
    }
  };

  consider('title', document.title);
  for (const tag of document.tags) consider('tag', tag);
  if (document.category) consider('category', document.category);
  for (const keyword of document.keywords) consider('keyword', keyword);

  return best;
}

/**
 * 在文档集合上执行搜索。
 *
 * 返回顺序完全确定：先按分数降序，分数相同再按标题字典序，最后按 id。最后那个 id 兜底不是
 * 洁癖 —— 没有它，分数与标题都相同的两条记录在不同运行中可能顺序不同，测试会随机失败。
 *
 * The ordering is fully deterministic: score descending, then title, then id. That final id
 * tiebreaker is not pedantry — without it two records with equal score and title can swap
 * order between runs and tests fail intermittently.
 */
export function searchDocuments(
  documents: readonly SearchDocument[],
  query: SearchQuery,
): readonly SearchHit[] {
  const needle = normalize(query.text);

  const candidates = query.kinds?.length
    ? documents.filter((document) => query.kinds!.includes(document.kind))
    : documents;

  // 空查询不是错误：§11 的搜索页在用户还没输入时要展示全部（配合最近使用排序）。
  // An empty query is not an error: before the user types, §11's search page shows everything
  // (ordered by recency).
  if (!needle) {
    const hits = candidates.map<SearchHit>((document) => ({
      document,
      score: 0,
      matchedOn: 'title',
      matchedText: document.title,
    }));
    return sortHits(hits).slice(0, query.limit ?? hits.length);
  }

  const hits: SearchHit[] = [];
  for (const document of candidates) {
    const hit = scoreDocument(document, needle);
    if (hit) hits.push(hit);
  }

  return sortHits(hits).slice(0, query.limit ?? hits.length);
}

function sortHits(hits: readonly SearchHit[]): SearchHit[] {
  return [...hits].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    const byTitle = a.document.title.localeCompare(b.document.title, 'zh-Hans-CN');
    if (byTitle !== 0) return byTitle;
    return a.document.id.localeCompare(b.document.id);
  });
}

/**
 * 按"最近使用"重排搜索结果（§11）。
 *
 * 与普通排序的区别：最近使用**只在分数相同时**起决定作用。否则一个很久以前用过、
 * 但跟当前查询几乎无关的服务会压倒真正匹配的结果 —— 那是搜索最令人恼火的行为之一。
 *
 * Recency only breaks ties; it never outranks relevance. Otherwise a long-ago-used service
 * that barely matches the query would beat a genuinely relevant one — one of search's most
 * irritating behaviours.
 */
export function orderByRecency(
  hits: readonly SearchHit[],
  recentIds: readonly string[],
): readonly SearchHit[] {
  const rank = new Map<string, number>();
  recentIds.forEach((id, index) => rank.set(id, index));

  return [...hits].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    const rankA = rank.get(a.document.ref.serviceId ?? a.document.id) ?? Number.MAX_SAFE_INTEGER;
    const rankB = rank.get(b.document.ref.serviceId ?? b.document.id) ?? Number.MAX_SAFE_INTEGER;
    if (rankA !== rankB) return rankA - rankB;
    return a.document.id.localeCompare(b.document.id);
  });
}
