/// 校园事务 / campus transactions (§8, §10).
///
/// §2.1 是这条设计的来源：**微信负责交流，Campulse 负责事务**。因此这里没有
/// Message/Body/Reply，只有三种结构化对象：Announcement、Event、Task，以及
/// §10 规定的结构化反馈取值。
///
/// This is where §2.1 lands: WeChat does conversation, Campulse does transactions. So
/// there is no Message, Body or Reply here — only three structured objects
/// (announcement, event, task) plus the §10 feedback value sets.
library;

import 'package:campus_mobile/data/models/json_utils.dart';

/// 事务种类 / the kind of transaction.
enum TransactionKind {
  announcement('announcement'),
  event('event'),
  task('task');

  const TransactionKind(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 事务类型应当可穷举，因此这里不提供未知兜底。
  /// Transaction kinds are meant to be exhaustive, so there is deliberately no
  /// unknown fallback.
  static TransactionKind? tryFromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final TransactionKind kind in values) {
      if (kind.wireValue == wire) return kind;
    }
    return null;
  }
}

/// 公告优先级 / announcement priority.
///
/// 四个取值与 `@campus/models` 的 `AnnouncementPriority` 一一对应。`urgent` 曾经缺失，
/// 后果是**紧急公告被降级成普通公告**（未知取值落回 [normal]）：语义上它意味着"可以突破
/// 安静时段推送"，丢了这一档，最该被看到的那条公告反而排在普通队列里。
///
/// The four values mirror `@campus/models`. `urgent` used to be missing, which silently demoted
/// urgent announcements to normal ones (unknown values fall back to [normal]) — losing the one
/// level that means "may bypass quiet hours", so the announcement that matters most queued like
/// any other.
enum AnnouncementPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const AnnouncementPriority(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [normal]。
  /// Parse a wire value, falling back to [normal].
  static AnnouncementPriority fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final AnnouncementPriority priority in values) {
      if (priority.wireValue == wire) return priority;
    }
    return AnnouncementPriority.normal;
  }

  /// 是否属于"必须让用户看见"的那一档 / whether this is the must-not-miss level.
  bool get isUrgent => this == AnnouncementPriority.urgent;
}

/// 任务状态（§10 Task 的四种取值）/ task status, the four §10 values.
enum TaskStatus {
  notStarted('not-started'),
  inProgress('in-progress'),
  /// 完成态。后端取值是 `done`（与 `@campus/models` 的 `TaskStatus` 一致），
  /// **不是** `completed`。
  ///
  /// Done. The wire value is `done`, matching `@campus/models`; it is not
  /// `completed`. The old value here did not match any backend payload, so a
  /// finished task silently fell back to [notStarted] and rendered as
  /// "not started" — a data-correctness bug, not a naming preference.
  done('done'),
  blocked('blocked');

  const TaskStatus(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [notStarted]。
  /// Parse a wire value, falling back to [notStarted].
  static TaskStatus fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final TaskStatus status in values) {
      if (status.wireValue == wire) return status;
    }
    return TaskStatus.notStarted;
  }
}

/// 公告 / an announcement (§8).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.publishedAt,
    this.sourceName,
  });

  /// 主键 / the id.
  final String id;

  /// 标题 / the title.
  final String title;

  /// 正文 / the body.
  final String body;

  /// 优先级 / the priority.
  final AnnouncementPriority priority;

  /// 发布时间 / when it was published.
  final DateTime publishedAt;

  /// 来源名称 / the source's name.
  final String? sourceName;

  /// 从后端 JSON 解析；缺少 `id` 时返回 null。
  /// Parse from the backend JSON; null when `id` is missing.
  static Announcement? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    return Announcement(
      id: id,
      title: asNonEmptyString(json['title']) ?? id,
      body: asString(json['content']) ?? asString(json['body']) ?? '',
      priority: AnnouncementPriority.fromWire(json['priority']),
      publishedAt: asDateTime(json['publishedAt']) ?? DateTime.now(),
      sourceName: asNonEmptyString(json['sourceName']),
    );
  }

  /// 解析公告数组 / parse an announcement array.
  static List<Announcement> listFromJson(Object? value) {
    return <Announcement>[
      for (final Map<String, Object?> row in asMapList(value))
        if (Announcement.tryFromJson(row) case final Announcement item) item,
    ];
  }
}

/// 活动 / an event (§8).
class CampusEvent {
  const CampusEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.location,
    this.relatedCourseId,
    this.sourceName,
    this.isScheduleChange = false,
    this.teachingWeek,
    this.dayOfWeek,
    this.periodStart,
    this.periodEnd,
  });

  /// 主键 / the id.
  final String id;

  /// 标题 / the title.
  final String title;

  /// 开始时间 / the start time.
  final DateTime startAt;

  /// 结束时间 / the end time.
  final DateTime endAt;

  /// 地点 / the location.
  final String? location;

  /// 关联课程 / the related course.
  final String? relatedCourseId;

  /// 来源名称 / the source's name.
  final String? sourceName;

  /// 是否为**调课/停课**产生的变更事件（§9）。
  ///
  /// §9 的例子「第七周周三调到文史楼 201」必须表达成一个指向原课程的事件，而**不是**就地
  /// 改写课程行：改写了，就再也说不清"这门课原本什么时候上"。
  ///
  /// Whether this event is a schedule change. §9's "week 7 Wednesday moved to Wenshi 201" must be
  /// an event pointing at the course rather than an in-place edit of it: editing destroys the
  /// answer to "when did this course originally meet".
  final bool isScheduleChange;

  /// 教学活动发生在第几教学周 / the teaching week this slot applies to.
  final int? teachingWeek;

  /// 星期几，`DateTime.monday`(1) … `DateTime.sunday`(7) / the weekday.
  final int? dayOfWeek;

  /// 起始节次 / the first period.
  final int? periodStart;

  /// 结束节次 / the last period.
  final int? periodEnd;

  /// 是否已经结束 / whether it is already over.
  bool isFinishedAt(DateTime now) => endAt.isBefore(now);

  /// 是否属于 [day] 这一天（按本地时间）。
  /// Whether this event falls on [day] in local time.
  bool occursOn(DateTime day) {
    final DateTime start = DateTime(startAt.year, startAt.month, startAt.day);
    final DateTime end = DateTime(endAt.year, endAt.month, endAt.day);
    final DateTime target = DateTime(day.year, day.month, day.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  /// 这条事件是否与第 [week] 教学周有关 / whether this event concerns teaching week [week].
  ///
  /// 判定刻意**保守**：
  ///   * 不是调课事件的（普通活动），一律算有关——它本来就不属于某一周；
  ///   * 是调课事件但**没给周次**的，也算有关：宁可多显示一条，也不要把一条可能相关的
  ///     变更藏起来（漏掉调课通知比多显示一条严重得多）。
  ///
  /// Deliberately conservative: a non-schedule-change event is always relevant (it belongs to no
  /// particular week), and a schedule change with no week given is also kept — showing one extra
  /// row beats hiding a real timetable change.
  bool concernsWeek(int week) {
    if (!isScheduleChange) return true;
    final int? target = teachingWeek;
    if (target == null) return true;
    return target == week;
  }

  /// 是否携带完整的教学槽位（周次 + 星期 + 节次）/ whether the academic slot is complete.
  bool get hasTeachingSlot =>
      teachingWeek != null &&
      dayOfWeek != null &&
      periodStart != null &&
      periodEnd != null &&
      dayOfWeek! >= DateTime.monday &&
      dayOfWeek! <= DateTime.sunday &&
      periodStart! <= periodEnd!;

  /// 从后端 JSON 解析；缺少 `id` 或时间时返回 null。
  /// Parse from the backend JSON; null when `id` or a timestamp is missing.
  static CampusEvent? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    final DateTime? startAt = asDateTime(json['startAt']);
    if (id == null || startAt == null) return null;
    return CampusEvent(
      id: id,
      title: asNonEmptyString(json['title']) ?? id,
      startAt: startAt,
      endAt: asDateTime(json['endAt']) ?? startAt,
      location: asNonEmptyString(json['location']),
      relatedCourseId: asNonEmptyString(json['relatedCourseId']),
      sourceName: asNonEmptyString(json['sourceName']),
      isScheduleChange: asBool(json['isScheduleChange']),
      teachingWeek: asInt(json['teachingWeek']),
      dayOfWeek: asInt(json['dayOfWeek']),
      periodStart: asInt(json['periodStart']),
      periodEnd: asInt(json['periodEnd']),
    );
  }

  /// 解析活动数组 / parse an event array.
  static List<CampusEvent> listFromJson(Object? value) {
    return <CampusEvent>[
      for (final Map<String, Object?> row in asMapList(value))
        if (CampusEvent.tryFromJson(row) case final CampusEvent item) item,
    ];
  }
}

/// 待办任务 / a task (§8).
class CampusTask {
  const CampusTask({
    required this.id,
    required this.title,
    required this.status,
    this.deadline,
    this.relatedCourseId,
    this.relatedEventId,
    this.sourceName,
  });

  /// 主键 / the id.
  final String id;

  /// 标题 / the title.
  final String title;

  /// 状态 / the status.
  final TaskStatus status;

  /// 截止时间 / the deadline.
  final DateTime? deadline;

  /// 关联课程 / the related course.
  final String? relatedCourseId;

  /// 关联活动 / the related event.
  final String? relatedEventId;

  /// 来源名称 / the source's name.
  final String? sourceName;

  /// 是否仍未完成 / whether it is still open.
  bool get isOpen => status != TaskStatus.done && status != TaskStatus.blocked;

  /// 距离 [now] 还有多少天；无截止时间返回 null。
  /// Days until the deadline relative to [now]; null when there is none.
  int? daysUntil(DateTime now) {
    final DateTime? due = deadline;
    if (due == null) return null;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.difference(today).inDays;
  }

  /// 从后端 JSON 解析；缺少 `id` 时返回 null。
  /// Parse from the backend JSON; null when `id` is missing.
  static CampusTask? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    return CampusTask(
      id: id,
      title: asNonEmptyString(json['title']) ?? id,
      status: TaskStatus.fromWire(json['status']),
      deadline: asDateTime(json['deadline']),
      relatedCourseId: asNonEmptyString(json['relatedCourseId']),
      relatedEventId: asNonEmptyString(json['relatedEventId']),
      sourceName: asNonEmptyString(json['sourceName']),
    );
  }

  /// 解析任务数组 / parse a task array.
  static List<CampusTask> listFromJson(Object? value) {
    return <CampusTask>[
      for (final Map<String, Object?> row in asMapList(value))
        if (CampusTask.tryFromJson(row) case final CampusTask item) item,
    ];
  }
}

/// 三类事务的统一视图 / a uniform view over the three transaction kinds.
///
/// 用 sealed class 而不是 `dynamic`：Inbox 的 `switch` 因此必须写全，漏掉一类
/// 事务会直接编译失败。
/// Sealed rather than `dynamic`, so Inbox's `switch` must be exhaustive and a
/// forgotten kind fails to compile.
sealed class CampusTransaction {
  const CampusTransaction();

  /// 事务种类 / the transaction kind.
  TransactionKind get kind;

  /// 稳定主键 / the stable id.
  String get id;

  /// 标题 / the title.
  String get title;

  /// 参与排序与"最近"展示的时间 / the time used for ordering.
  DateTime get occurredAt;

  /// 供 §11 本地过滤使用的检索文本 / the haystack for §11's local filtering.
  String get searchHaystack => '$title $kind'.toLowerCase();
}

/// 公告作为事务 / an announcement as a transaction.
class AnnouncementTransaction extends CampusTransaction {
  const AnnouncementTransaction(this.announcement);

  /// 底层公告 / the underlying announcement.
  final Announcement announcement;

  @override
  TransactionKind get kind => TransactionKind.announcement;

  @override
  String get id => announcement.id;

  @override
  String get title => announcement.title;

  @override
  DateTime get occurredAt => announcement.publishedAt;

  @override
  String get searchHaystack =>
      '${announcement.title} ${announcement.body} ${announcement.sourceName ?? ''}'
          .toLowerCase();
}

/// 活动作为事务 / an event as a transaction.
class EventTransaction extends CampusTransaction {
  const EventTransaction(this.event);

  /// 底层活动 / the underlying event.
  final CampusEvent event;

  @override
  TransactionKind get kind => TransactionKind.event;

  @override
  String get id => event.id;

  @override
  String get title => event.title;

  @override
  DateTime get occurredAt => event.startAt;

  @override
  String get searchHaystack =>
      '${event.title} ${event.location ?? ''} ${event.sourceName ?? ''}'.toLowerCase();
}

/// 任务作为事务 / a task as a transaction.
class TaskTransaction extends CampusTransaction {
  const TaskTransaction(this.task);

  /// 底层任务 / the underlying task.
  final CampusTask task;

  @override
  TransactionKind get kind => TransactionKind.task;

  @override
  String get id => task.id;

  @override
  String get title => task.title;

  @override
  DateTime get occurredAt => task.deadline ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String get searchHaystack => '${task.title} ${task.sourceName ?? ''}'.toLowerCase();
}

/// 把三类数据合成一份事务列表，并按时间排序。
/// Merge the three data sets into one transaction list, ordered by time.
List<CampusTransaction> mergeTransactions({
  required List<Announcement> announcements,
  required List<CampusEvent> events,
  required List<CampusTask> tasks,
}) {
  final List<CampusTransaction> merged = <CampusTransaction>[
    for (final Announcement announcement in announcements)
      AnnouncementTransaction(announcement),
    for (final CampusEvent event in events) EventTransaction(event),
    for (final CampusTask task in tasks) TaskTransaction(task),
  ];
  merged.sort((CampusTransaction a, CampusTransaction b) {
    final int byTime = b.occurredAt.compareTo(a.occurredAt);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  });
  return merged;
}
