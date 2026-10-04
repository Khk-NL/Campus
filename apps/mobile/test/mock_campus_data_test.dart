import 'package:campus_mobile/data/repositories/mock_campus_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo announcements have distinct IDs', () {
    final ids = buildMockAnnouncements().map((announcement) => announcement.id);
    expect(ids.toSet().length, ids.length);
  });

  test('built-in courses are explicitly marked as demo data', () {
    expect(buildMockCourses().every((course) => course.isDemo), isTrue);
  });
}
