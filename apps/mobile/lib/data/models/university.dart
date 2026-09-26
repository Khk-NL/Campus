/// 高校 / a university (§6 University).
///
/// `config` 描述这所学校的教学日历口径与已声明能力。Campulse Core 只把它当数据用，
/// 不为任何一所学校写分支。
///
/// `config` describes the school's calendar conventions and declared capabilities.
/// Campulse Core only reads it as data; it never branches on a specific school.
library;

import 'package:campus_mobile/data/models/json_utils.dart';
import 'package:campus_mobile/data/models/period_schedule.dart';
import 'package:campus_mobile/data/models/service_enums.dart';

/// 一周从哪天开始 / which day a week starts on.
enum WeekStart {
  monday('monday'),
  sunday('sunday');

  const WeekStart(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;

  /// 按后端取值解析，未知取值落到 [monday]。
  /// Parse a wire value, falling back to [monday].
  static WeekStart fromWire(Object? value) {
    final String? wire = value is String ? value : null;
    for (final WeekStart start in values) {
      if (start.wireValue == wire) return start;
    }
    return WeekStart.monday;
  }
}

/// 高校配置对象 / the university's configuration object.
class UniversityConfigData {
  const UniversityConfigData({
    required this.termWeeks,
    required this.periodsPerDay,
    required this.weekStartsOn,
    required this.timezone,
    required this.locales,
    required this.capabilities,
    this.firstPeriodStart = '08:00',
    this.periodMinutes = 45,
  });

  /// 一学期教学周数 / teaching weeks per term.
  final int termWeeks;

  /// 每天节次数 / periods per day.
  final int periodsPerDay;

  /// 一周起始日 / the first day of a week.
  final WeekStart weekStartsOn;

  /// IANA 时区名 / the IANA time zone name.
  final String timezone;

  /// 支持的语言 / supported locales.
  final List<String> locales;

  /// 已声明能力（§3.2 Provider 概念）/ declared capabilities (§3.2).
  final List<String> capabilities;

  /// 第一节课的墙上时刻，`HH:mm` / the wall-clock start of period 1.
  ///
  /// 默认值 `08:00` 与后端 `university.first_period_start` 的列默认值一致——客户端**不该**有
  /// 自己的作息意见，这里只是在后端没发这个字段时保持与它相同的兜底。
  ///
  /// The `08:00` default matches the backend column's default: the client holds no opinion about
  /// a school's timetable, it merely falls back to the same value when the field is absent.
  final String firstPeriodStart;

  /// 单节时长（分钟）/ the length of one period in minutes.
  final int periodMinutes;

  /// 节次 ↔ 时刻的查询对象 / the period-to-clock-time query object.
  ///
  /// 首页 Today、日历、上课提醒、ICS 导出都通过它拿时间，因此**换口径只改这一处**：
  /// 将来有真实作息表（大节/小节、不等长课间）时换掉实现即可，调用方一行不改。
  ///
  /// Home's Today, the calendar, reminders and ICS export all read times through this, so a
  /// change of reading touches **this one place**: when a real timetable with unequal breaks
  /// arrives, swapping the implementation changes no caller.
  PeriodSchedule get periodSchedule => EvenPeriodSchedule(
        firstPeriodStart: firstPeriodStart,
        periodMinutes: periodMinutes,
        periodsPerDay: periodsPerDay,
      );

  /// 从后端 JSON 解析，缺失字段用保守默认值。
  /// Parse from the backend JSON, using conservative defaults for missing fields.
  static UniversityConfigData fromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    return UniversityConfigData(
      termWeeks: asIntOr(json['termWeeks'], 18),
      // 缺省值必须与后端列默认值一致（`periods_per_day` 目前是 13），否则离线与在线会在
      // "一天有几节"上给出不同答案，而课表网格的行数正好由它决定。
      //
      // The fallback must match the backend column default (`periods_per_day` is 13 today), or
      // offline and online disagree about how many periods a day has — which is exactly what
      // decides how many rows the grid draws.
      periodsPerDay: asIntOr(json['periodsPerDay'], 13),
      weekStartsOn: WeekStart.fromWire(json['weekStartsOn']),
      timezone: asNonEmptyString(json['timezone']) ?? 'Asia/Shanghai',
      locales: asStringList(json['locales']),
      capabilities: asStringList(json['capabilities']),
      firstPeriodStart: asNonEmptyString(json['firstPeriodStart']) ?? '08:00',
      periodMinutes: asIntOr(json['periodMinutes'], 45),
    );
  }
}

/// 与后端形状一致的高校 / a university shaped like the backend's.
class University {
  const University({
    required this.id,
    required this.name,
    required this.shortName,
    required this.domain,
    required this.config,
    required this.status,
    this.logoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// 高校主键，也是 `universityId` 查询参数的值 / the id, also the query value.
  final String id;

  /// 全称 / the full name.
  final String name;

  /// 简称 / the short name.
  final String shortName;

  /// 官方域名 / the official domain.
  final String domain;

  /// 图标 / a logo URL.
  final String? logoUrl;

  /// 配置 / the configuration.
  final UniversityConfigData config;

  /// 记录状态 / the record status.
  final RecordStatus status;

  /// 创建时间 / creation time.
  final DateTime? createdAt;

  /// 更新时间 / last update time.
  final DateTime? updatedAt;

  /// 从后端 JSON 解析；缺少 `id` 时返回 null。
  /// Parse from the backend JSON; null when `id` is missing.
  static University? tryFromJson(Object? value) {
    final Map<String, Object?> json = asMap(value);
    final String? id = asNonEmptyString(json['id']);
    if (id == null) return null;
    return University(
      id: id,
      name: asNonEmptyString(json['name']) ?? id,
      shortName: asNonEmptyString(json['shortName']) ?? id,
      domain: asString(json['domain']) ?? '',
      logoUrl: asNonEmptyString(json['logoUrl']),
      config: UniversityConfigData.fromJson(json['config']),
      status: RecordStatus.fromWire(json['status']),
      createdAt: asDateTime(json['createdAt']),
      updatedAt: asDateTime(json['updatedAt']),
    );
  }

  /// 解析高校数组 / parse a university array.
  static List<University> listFromJson(Object? value) {
    return <University>[
      for (final Map<String, Object?> row in asMapList(value))
        if (University.tryFromJson(row) case final University university) university,
    ];
  }

  @override
  String toString() => 'University($id, $name)';
}
