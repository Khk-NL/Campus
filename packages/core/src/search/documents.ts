/**
 * 统一搜索的文档模型（文档 §11）
 *
 * §11 强调统一搜索是 Campus 区别于"收藏夹"的关键能力，搜索对象横跨
 * 服务 / 应用 / 课程 / 公告 / 活动 / 任务。这些实体的字段差异极大，因此先把它们
 * 归一成一种**扁平的、可比较的文档**，搜索算法只需要认识这一种形状。
 *
 * §11 calls unified search the thing that separates Campus from a bookmark folder, and the
 * targets span services, apps, courses, announcements, events and tasks. Their fields differ
 * wildly, so each is normalised into one flat, comparable document shape that the search
 * algorithm is the only consumer of.
 */
import type { CampusService } from '@campus/models';

/** 搜索结果可归属的类别 / the kinds a result can belong to */
export type SearchableKind =
  | 'service'
  | 'campus-app'
  | 'course'
  | 'announcement'
  | 'event'
  | 'task';

/** 归一化后的可搜索文档 / a normalised, searchable document */
export interface SearchDocument {
  readonly id: string;
  readonly kind: SearchableKind;
  /** 主标题，权重最高 / the title, weighted highest */
  readonly title: string;
  /** 副标题，仅用于展示，不参与匹配 / subtitle, display only — never matched */
  readonly subtitle?: string;
  readonly tags: readonly string[];
  readonly category?: string;
  /** 额外关键词（例如教师名、地点）/ extra keywords such as a teacher or a room */
  readonly keywords: readonly string[];
  /** 原始对象的引用，便于 UI 直接跳转 / the underlying object, so the UI can navigate */
  readonly ref: { readonly serviceId?: string };
}

/**
 * 把校园服务转成搜索文档（§11 的服务对象）。
 *
 * 注意 `description` **不**参与匹配：描述文本长且噪音大，把它纳入匹配会让
 * "图书馆"这种查询返回一堆只顺带提过图书馆的服务，直接损害结果可信度。
 *
 * Note that `description` is deliberately NOT matched: descriptions are long and noisy, and
 * including them makes a query like "library" return everything that merely mentions one,
 * which destroys trust in the results.
 */
export function serviceToSearchDocument(service: CampusService): SearchDocument {
  return {
    id: `service:${service.id}`,
    kind: 'service',
    title: service.name,
    subtitle: service.description,
    tags: service.tags,
    category: service.category,
    keywords: [service.origin, service.type],
    ref: { serviceId: service.id },
  };
}

/** 批量转换，便于构建索引 / batch conversion for index building */
export function servicesToSearchDocuments(
  services: readonly CampusService[],
): readonly SearchDocument[] {
  return services.map(serviceToSearchDocument);
}
