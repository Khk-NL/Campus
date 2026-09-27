import 'dart:convert';
import 'dart:io';

import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/pocketbase_campus_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('邮箱重复注册提示登录或重发，不继续请求邮件', () async {
    final List<String> paths = <String>[];
    final transport = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({
          'message': 'Failed to create record.',
          'data': {
            'email': {'code': 'validation_not_unique'},
          },
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = PocketBaseCampusRepository(
      client: PocketBase(
        'https://example.test',
        httpClientFactory: () => transport,
      ),
    );
    try {
      await expectLater(
        repository.register('student@example.test', 'password'),
        throwsA(
          isA<CampusAccountException>().having(
            (error) => error.message,
            'message',
            contains('不要重复注册'),
          ),
        ),
      );
      expect(paths, ['/api/collections/users/records']);
    } finally {
      repository.dispose();
      transport.close();
    }
  });

  test('账号创建成功但邮件响应失败时保留已创建状态提示', () async {
    final transport = MockClient((request) async {
      return request.url.path.endsWith('/records')
          ? http.Response(
              jsonEncode({'id': 'newstudent12345'}),
              200,
              headers: {'content-type': 'application/json'},
            )
          : http.Response(
              '{"message":"mail unavailable"}',
              500,
              headers: {'content-type': 'application/json'},
            );
    });
    final repository = PocketBaseCampusRepository(
      client: PocketBase(
        'https://example.test',
        httpClientFactory: () => transport,
      ),
    );
    try {
      await expectLater(
        repository.register('student@example.test', 'password'),
        throwsA(
          isA<CampusAccountException>().having(
            (error) => error.message,
            'message',
            contains('账号已创建'),
          ),
        ),
      );
    } finally {
      repository.dispose();
      transport.close();
    }
  });

  test('HTTPS 握手错误不误报为 SMTP 或证书错误', () async {
    final transport = MockClient((request) async {
      throw const HandshakeException('Connection terminated during handshake');
    });
    final repository = PocketBaseCampusRepository(
      client: PocketBase(
        'https://example.test',
        httpClientFactory: () => transport,
      ),
    );
    try {
      expect(await repository.probe(), DataSourceMode.mock);
      expect(repository.lastConnectionError, contains('HTTPS 握手失败'));
      await expectLater(
        repository.register('student@example.test', 'password'),
        throwsA(
          isA<CampusAccountException>().having(
            (error) => error.message,
            'message',
            contains('HTTPS 握手失败'),
          ),
        ),
      );
    } finally {
      repository.dispose();
      transport.close();
    }
  });

  test('普通用户注册后请求邮箱验证，密码重置走 users 集合', () async {
    final List<String> paths = <String>[];
    final MockClient transport = MockClient((http.Request request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/records')) {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'student@example.test');
        expect(body['password'], body['passwordConfirm']);
        return http.Response(
          jsonEncode(<String, Object>{
            'id': 'newstudent12345',
            'collectionId': 'users1234567890',
            'collectionName': 'users',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('', 204);
    });
    final PocketBaseCampusRepository repository = PocketBaseCampusRepository(
      client: PocketBase(
        'http://example.test',
        httpClientFactory: () => transport,
      ),
    );
    try {
      await repository.register('student@example.test', 'test-password');
      await repository.requestPasswordReset('student@example.test');
      expect(paths, <String>[
        '/api/collections/users/records',
        '/api/collections/users/request-verification',
        '/api/collections/users/request-password-reset',
      ]);
    } finally {
      repository.dispose();
      transport.close();
    }
  });

  test('PocketBase 内容适配器解析课程与服务，并标识演示来源', () async {
    final MockClient transport = MockClient((http.Request request) async {
      final String filter = request.url.queryParameters['filter'] ?? '';
      final String kind = filter.contains('course')
          ? 'course'
          : filter.contains('service')
          ? 'service'
          : 'university';
      final Map<String, Object?> payload = switch (kind) {
        'course' => <String, Object?>{
          'name': '测试课程',
          'teacher': '教师',
          'location': '教室',
          'startWeek': 1,
          'endWeek': 18,
        },
        'service' => <String, Object?>{
          'name': '测试服务',
          'description': '服务说明',
          'category': 'official-hub',
          'type': 'web',
          'launchTarget': <String, Object?>{
            'type': 'web',
            'url': 'https://example.org/',
          },
          'isOfficial': false,
          'origin': 'external',
          'sourceSystem': 'manual',
          'tags': <String>[],
          'status': 'active',
        },
        _ => <String, Object?>{
          'name': '测试大学',
          'shortName': 'TEST',
          'status': 'active',
        },
      };
      final String body = jsonEncode(<String, Object?>{
        'page': 1,
        'perPage': 1000,
        'totalPages': 1,
        'totalItems': 1,
        'items': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'testrecord00001',
            'collectionId': 'testcollection01',
            'collectionName': 'campus_content',
            'universityId': 'ecnu',
            'kind': kind,
            'demo': true,
            'payload': payload,
          },
        ],
      });
      return http.Response(
        body,
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final PocketBase client = PocketBase(
      'http://example.test',
      httpClientFactory: () => transport,
    );
    final PocketBaseCampusRepository repository = PocketBaseCampusRepository(
      client: client,
    );
    try {
      final courses = await repository.fetchCourses();
      expect(courses.single.name, '测试课程');
      expect(courses.single.id, 'testrecord00001');
      expect(
        repository.sourceMode(DataSourceSource.courses),
        DataSourceMode.mock,
      );

      final services = await repository.listServices(
        const CampusServicesQuery(universityId: 'ecnu'),
      );
      expect(services.single.name, '测试服务');
      expect(
        repository.sourceMode(DataSourceSource.services),
        DataSourceMode.mock,
      );
    } finally {
      repository.dispose();
      transport.close();
    }
  });
}
