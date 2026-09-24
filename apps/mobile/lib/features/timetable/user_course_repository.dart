import 'package:campus_mobile/data/models/course.dart';
import 'package:pocketbase/pocketbase.dart';

/// Personal timetable storage, kept separate from the public campus catalogue.
abstract class UserCourseRepository {
  Future<void> create(Course course);
}

class PocketBaseUserCourseRepository implements UserCourseRepository {
  PocketBaseUserCourseRepository(this.client);

  final PocketBase client;

  @override
  Future<void> create(Course course) async {
    final String? owner = client.authStore.record?.id;
    if (owner == null || !client.authStore.isValid) {
      throw StateError('请先登录');
    }
    await client
        .collection('user_courses')
        .create(
          body: <String, dynamic>{
            'owner': owner,
            'schemaVersion': 1,
            'payload': <String, dynamic>{
              'name': course.name,
              'universityId': course.universityId,
              'teacher': course.teacher,
              'location': course.location,
              'startWeek': course.startWeek,
              'endWeek': course.endWeek,
              'weekday': course.weekday,
              'startPeriod': course.startPeriod,
              'endPeriod': course.endPeriod,
              'scheduleRule': course.scheduleRule,
              'scheduleRules': <Map<String, dynamic>>[
                for (final CourseScheduleRule rule
                    in course.scheduleRules ?? const <CourseScheduleRule>[])
                  <String, dynamic>{
                    'startWeek': rule.startWeek,
                    'endWeek': rule.endWeek,
                    'parity': rule.parity.wireValue,
                    if (rule.weeks != null) 'weeks': rule.weeks,
                    'dayOfWeek': rule.dayOfWeek,
                    'periodStart': rule.periodStart,
                    'periodEnd': rule.periodEnd,
                    'location': rule.location,
                    'teacher': rule.teacher,
                  },
              ],
            },
          },
        );
  }
}
