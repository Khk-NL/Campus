import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/repositories/in_memory_campus_repository.dart';
import 'package:campus_mobile/features/home/widgets/quick_access_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingRepository extends InMemoryCampusRepository {
  int nameReads = 0;

  @override
  Future<Map<String, LocalizedText>> fetchServiceNames() {
    nameReads++;
    return super.fetchServiceNames();
  }
}

void main() {
  testWidgets('quick access keeps its name request across parent rebuilds', (
    WidgetTester tester,
  ) async {
    final _CountingRepository repository = _CountingRepository();
    final List<CampusService> services = <CampusService>[];

    Widget page(List<CampusService> entries) => MaterialApp(
      home: Scaffold(
        body: QuickAccessGrid(services: entries, repository: repository),
      ),
    );

    await tester.pumpWidget(page(services));
    await tester.pumpWidget(page(services));
    expect(repository.nameReads, 1);

    await tester.pumpWidget(page(<CampusService>[]));
    expect(repository.nameReads, 2);
  });
}
