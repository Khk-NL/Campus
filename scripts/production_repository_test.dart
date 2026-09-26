import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/pocketbase_course_note_repository.dart';
import 'package:campus_mobile/data/repositories/pocketbase_campus_repository.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/timetable/course_csv_import.dart';
import 'package:campus_mobile/features/timetable/user_course_repository.dart';
import 'package:campus_mobile/core/config/university_config.dart';

void main() {
 test('production repositories: real notes sync and catalog parsing', () async {
  final users=jsonDecode(File(Platform.environment['CAMPULSE_TEST_USERS']!).readAsStringSync()) as List;
  final a=PocketBase('https://campus.scsldr.cn');
  final a2=PocketBase('https://campus.scsldr.cn');
  final b=PocketBase('https://campus.scsldr.cn');
  for(final pair in [(a,users[0]),(a2,users[0]),(b,users[1])]){
   await pair.$1.collection('users').authWithPassword(pair.$2['email'] as String,pair.$2['password'] as String);
  }
  final notes=PocketBaseCourseNoteRepository(a);
  final second=PocketBaseCourseNoteRepository(a2);
  final other=PocketBaseCourseNoteRepository(b);
  final course='acceptance-${DateTime.now().millisecondsSinceEpoch}';
  final note=await notes.save(CourseNote(id:'',courseId:course,title:'Repository acceptance',content:'revision one',updatedAt:DateTime.now()));
  try {
   expect((await second.list(course)).single.content,'revision one');
   await notes.save(note.copyWith(content:'revision two'));
   expect((await second.list(course)).single.content,'revision two');
   expect(await other.list(course),isEmpty);
   final repo=PocketBaseCampusRepository(client:a);
   await repo.fetchCampusApps(const CampusAppsQuery());
   expect(repo.mode,DataSourceMode.remote);
   repo.dispose();
   final imported=CourseCsvImport.parse('课程名称,教师,地点,星期,开始节次,结束节次,开始周,结束周\n$course,验收教师,验收教室,周一,1,2,1,16',universityId:UniversityConfigs.defaultConfig.universityId,termWeeks:16).single.course!;
   await PocketBaseUserCourseRepository(a).create(imported);
   final records=await a.collection('user_courses').getFullList();
   final created=records.singleWhere((r)=>(r.data['payload'] as Map)['name']==course);
   try {
    final secondRepo=PocketBaseCampusRepository(client:a2);
    final foreignRepo=PocketBaseCampusRepository(client:b);
    final persisted=(await secondRepo.fetchCourses()).singleWhere((c)=>c.name==course);
    expect(persisted.id,created.id);
    expect(persisted.location,'验收教室');
    expect((await foreignRepo.fetchCourses()).where((c)=>c.name==course),isEmpty);
    secondRepo.dispose();foreignRepo.dispose();
   } finally { await a.collection('user_courses').delete(created.id); }
  } finally { await notes.delete(note.id); }
 },timeout:const Timeout(Duration(minutes:2)));
}
