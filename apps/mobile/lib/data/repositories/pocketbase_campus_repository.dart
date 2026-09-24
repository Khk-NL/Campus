import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/http/campus_api_client.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// MVP 的 PocketBase 适配器。页面仍只依赖 CampusRepository，方便以后替换后端。
class PocketBaseCampusRepository
    implements
        CampusRepository,
        CampusAccountRepository,
        CampusProbeRepository {
  PocketBaseCampusRepository({
    required this.client,
    InMemoryCampusRepository? fallback,
  }) : _fallback = fallback ?? InMemoryCampusRepository();

  final PocketBase client;
  final InMemoryCampusRepository _fallback;
  final ValueNotifier<DataSourceMode> _mode = ValueNotifier(
    DataSourceMode.unknown,
  );
  final ValueNotifier<int> _sourceNotifier = ValueNotifier(0);
  final Map<DataSourceSource, DataSourceMode> _sourceModes = {};

  @override
  DataSourceMode get mode => _mode.value;

  @override
  Listenable get modeChanges => _mode;

  @override
  Listenable get sourceChanges => _sourceNotifier;

  @override
  DataSourceMode sourceMode(DataSourceSource source) =>
      _sourceModes[source] ?? _mode.value;

  @override
  Future<DataSourceMode> probe() async {
    try {
      await client.collection('campus_content').getList(page: 1, perPage: 1);
      _mode.value = DataSourceMode.remote;
    } on ClientException {
      _mode.value = DataSourceMode.mock;
    }
    return _mode.value;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.collection('users').authWithPassword(email, password);
  }

  @override
  void signOut() => client.authStore.clear();

  @override
  Future<AppUser?> fetchCurrentUser() async {
    if (!client.authStore.isValid) return null;
    final RecordModel? record = client.authStore.record;
    if (record == null) return null;
    final String email = record.data['email'] as String? ?? '';
    final String name = record.data['name'] as String? ?? '';
    return AppUser(
      id: record.id,
      universityId: UniversityConfigs.defaultConfig.universityId,
      externalUserId: '',
      name: name.isNotEmpty ? name : (email.isNotEmpty ? email : '试点用户'),
      roles: const <PlatformRole>[PlatformRole.user],
    );
  }

  Future<List<_ContentRow>> _read(String kind, DataSourceSource source) async {
    final String universityId = UniversityConfigs.defaultConfig.universityId;
    final List<RecordModel> records = await client
        .collection('campus_content')
        .getFullList(
          filter: client.filter(
            'kind = {:kind} && universityId = {:universityId}',
            <String, dynamic>{'kind': kind, 'universityId': universityId},
          ),
        );
    _mode.value = DataSourceMode.remote;
    _setSource(
      source,
      records.isNotEmpty &&
              records.every((record) => record.data['demo'] == true)
          ? DataSourceMode.mock
          : DataSourceMode.remote,
    );
    return <_ContentRow>[
      for (final RecordModel record in records)
        if (record.data['payload'] is Map)
          _ContentRow(<String, dynamic>{
            ...Map<String, dynamic>.from(record.data['payload'] as Map),
            'id': record.id,
            'universityId': record.data['universityId'],
          }),
    ];
  }

  void _setSource(DataSourceSource source, DataSourceMode next) {
    if (_sourceModes[source] == next) return;
    _sourceModes[source] = next;
    _sourceNotifier.value++;
  }

  Future<T> _withFallback<T>(
    DataSourceSource source,
    Future<T> Function() remote,
    Future<T> Function() fallback,
  ) async {
    try {
      return await remote();
    } on ClientException {
      _mode.value = DataSourceMode.mock;
      _setSource(source, DataSourceMode.mock);
      return fallback();
    }
  }

  @override
  Future<List<University>> fetchUniversities() => _withFallback(
    DataSourceSource.services,
    () async => University.listFromJson(
      (await _read(
        'university',
        DataSourceSource.services,
      )).map((_ContentRow row) => row.payload).toList(),
    ),
    _fallback.fetchUniversities,
  );

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) =>
      _withFallback(DataSourceSource.services, () async {
        final List<CampusService> services =
            CampusService.listFromJson(
                  (await _read(
                    'service',
                    DataSourceSource.services,
                  )).map((_ContentRow row) => row.payload).toList(),
                )
                .where(
                  (CampusService item) =>
                      item.status.isVisible &&
                      item.universityId == query.universityId,
                )
                .toList();
        if (query.category != null) {
          services.removeWhere(
            (CampusService item) => item.category != query.category,
          );
        }
        final String text = (query.text ?? '').trim().toLowerCase();
        if (text.isNotEmpty) {
          services.removeWhere(
            (CampusService item) => !item.searchHaystack.contains(text),
          );
        }
        switch (query.sort) {
          case ServiceSortOrder.name:
            services.sort(
              (CampusService a, CampusService b) => a.name.compareTo(b.name),
            );
          case ServiceSortOrder.recent:
            services.sort(
              (CampusService a, CampusService b) =>
                  (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(
                        a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                      ),
            );
        }
        return query.limit == null
            ? services
            : services.take(query.limit!).toList();
      }, () => _fallback.listServices(query));

  @override
  Future<Map<String, LocalizedText>> fetchServiceNames() async => const {};

  @override
  Future<Map<String, LocalizedText>> fetchServiceDescriptions() async =>
      const {};

  @override
  Future<List<Course>> fetchCourses() => _withFallback(
    DataSourceSource.courses,
    () async => Course.listFromJson(
      (await _read(
        'course',
        DataSourceSource.courses,
      )).map((_ContentRow row) => row.payload).toList(),
    ),
    _fallback.fetchCourses,
  );

  @override
  Future<List<Announcement>> fetchAnnouncements() => _withFallback(
    DataSourceSource.announcements,
    () async => Announcement.listFromJson(
      (await _read(
        'announcement',
        DataSourceSource.announcements,
      )).map((_ContentRow row) => row.payload).toList(),
    ),
    _fallback.fetchAnnouncements,
  );

  @override
  Future<List<CampusEvent>> fetchEvents() => _withFallback(
    DataSourceSource.events,
    () async => CampusEvent.listFromJson(
      (await _read(
        'event',
        DataSourceSource.events,
      )).map((_ContentRow row) => row.payload).toList(),
    ),
    _fallback.fetchEvents,
  );

  @override
  Future<List<CampusTask>> fetchTasks() => _withFallback(
    DataSourceSource.tasks,
    () async => CampusTask.listFromJson(
      (await _read(
        'task',
        DataSourceSource.tasks,
      )).map((_ContentRow row) => row.payload).toList(),
    ),
    _fallback.fetchTasks,
  );

  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) =>
      _withFallback(DataSourceSource.apps, () async {
        final List<CampusApp> apps = CampusApp.listFromJson(
          (await _read(
            'app',
            DataSourceSource.apps,
          )).map((_ContentRow row) => row.payload).toList(),
        );
        if (query.tag != null && query.tag!.isNotEmpty) {
          apps.removeWhere((CampusApp app) => !app.tags.contains(query.tag));
        }
        switch (query.sort) {
          case CampusAppSortOrder.name:
            apps.sort((CampusApp a, CampusApp b) => a.name.compareTo(b.name));
          case CampusAppSortOrder.latest:
          case CampusAppSortOrder.recentlyUpdated:
          case CampusAppSortOrder.mostUsed:
            apps.sort(
              (CampusApp a, CampusApp b) =>
                  (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(
                        a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                      ),
            );
        }
        return query.limit == null ? apps : apps.take(query.limit!).toList();
      }, () => _fallback.fetchCampusApps(query));

  // 热度需要服务端原子计数；MVP 不在客户端直接改公开内容记录。
  @override
  Future<void> recordServiceOpen(String serviceId) async {}

  @override
  Future<void> recordAppOpen(String appId) async {}

  @override
  void dispose() {
    _mode.dispose();
    _sourceNotifier.dispose();
    _fallback.dispose();
  }
}

class _ContentRow {
  const _ContentRow(this.payload);
  final Map<String, dynamic> payload;
}
