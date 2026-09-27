import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:campus_mobile/data/repositories/pocketbase_campus_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('production ordinary registration and verification request', () async {
    final values = <String, String>{};
    for (final line in File(
      Platform.environment['CAMPULSE_ACCEPTANCE_ENV']!,
    ).readAsLinesSync()) {
      final split = line.indexOf('=');
      if (split > 0 && !line.trimLeft().startsWith('#')) {
        values[line.substring(0, split).trim()] = line
            .substring(split + 1)
            .trim()
            .replaceAll(RegExp(r'''^['"]|['"]$'''), '');
      }
    }
    final admin = PocketBase('https://campus.scsldr.cn');
    await admin
        .collection('_superusers')
        .authWithPassword(
          values['REMOTE_ADMIN_EMAIL']!,
          values['REMOTE_ADMIN_PASSWORD']!,
        );
    final email = values['REMOTE_ADMIN_EMAIL']!;
    final existing = await admin
        .collection('users')
        .getList(
          filter: admin.filter('email = {:email}', {'email': email}),
          perPage: 1,
        );
    final repo = PocketBaseCampusRepository(
      client: PocketBase('https://campus.scsldr.cn'),
    );
    try {
      if (existing.items.isEmpty) {
        final random = Random.secure();
        final password = base64UrlEncode(
          List<int>.generate(24, (_) => random.nextInt(256)),
        );
        // Store before transmission so a lost response cannot orphan the test credentials.
        File(Platform.environment['CAMPULSE_MAIL_PROBE_OUTPUT']!)
            .writeAsStringSync(
              jsonEncode({
                'email': email,
                'password': password,
                'purpose': 'ordinary email verification acceptance',
              }),
            );
        await repo.register(email, password);
      } else {
        await repo.requestVerification(email);
      }
      final rows = await admin
          .collection('users')
          .getList(
            filter: admin.filter('email = {:email}', {'email': email}),
            perPage: 1,
          );
      expect(rows.items, hasLength(1));
      print(
        'Ordinary account exists; Dart SDK verification request succeeded. Mailbox delivery is not asserted.',
      );
    } finally {
      repo.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
