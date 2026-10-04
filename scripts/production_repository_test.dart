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
import 'package:campus_mobile/features/study/pocketbase_study_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';

void main() {
 final baseUrl=Platform.environment['CAMPULSE_TEST_BASE_URL'] ?? 'https://campus.scsldr.cn';
 test('production plans: completion sync, restoration and user isolation', () async {
  final users=jsonDecode(File(Platform.environment['CAMPULSE_TEST_USERS']!).readAsStringSync()) as List;
  final a=PocketBase(baseUrl);
  final a2=PocketBase(baseUrl);
  final b=PocketBase(baseUrl);
  for(final pair in [(a,users[0]),(a2,users[0]),(b,users[1])]){
   await pair.$1.collection('users').authWithPassword(pair.$2['email'] as String,pair.$2['password'] as String);
  }
  final store=PocketBaseStudyRepository(a);
  final second=PocketBaseStudyRepository(a2);
  final original=await a.collection('study_workspaces').getFullList();
  final workspace=await store.load();
  final id='plan-acceptance-${DateTime.now().microsecondsSinceEpoch}';
  String? createdRecordId;
  workspace.activities.add(StudyActivity(id:id,course:'验收',title:'验收计划',objective:'',deadline:'2026-10-01',source:'personal',priority:2,tags:['验收'],subtasks:[const StudySubtask(title:'子任务',done:true)]));
  try {
   await store.save(workspace);
   if(original.isEmpty){
    final records=await a.collection('study_workspaces').getFullList();
    createdRecordId=records.singleWhere((record){
     final payload=record.data['payload'] as Map;
     return (payload['activities'] as List).any((task)=>(task as Map)['id']==id);
    }).id;
   }
   expect((await second.load()).activities.singleWhere((x)=>x.id==id).priority,2);
   final index=workspace.activities.indexWhere((x)=>x.id==id);
   workspace.activities[index]=workspace.activities[index].copyWith(completed:true);
   await store.save(workspace);
   final archived=(await second.load()).activities.singleWhere((x)=>x.id==id);
   expect(archived.isCompleted,isTrue);
   expect(archived.subtasks.single.done,isTrue);
   expect((await PocketBaseStudyRepository(b).load()).activities.where((x)=>x.id==id),isEmpty);
   workspace.activities[index]=archived.copyWith(completed:false);
   await store.save(workspace);
   expect((await second.load()).activities.singleWhere((x)=>x.id==id).isCompleted,isFalse);
  } finally {
   workspace.activities.removeWhere((x)=>x.id==id);
   if(original.isNotEmpty){await store.save(workspace);}
   else if(createdRecordId!=null){await a.collection('study_workspaces').delete(createdRecordId);}
  }
 },timeout:const Timeout(Duration(minutes:2)));
 test('production repositories: real notes sync and catalog parsing', () async {
  final users=jsonDecode(File(Platform.environment['CAMPULSE_TEST_USERS']!).readAsStringSync()) as List;
  final a=PocketBase(baseUrl);
  final a2=PocketBase(baseUrl);
  final b=PocketBase(baseUrl);
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
   final imported=CourseCsvImport.parse('课程名称,教师,地点,星期,开始节次,结束节次,开始周,结束周\n$course,验收教师,验收教室,周一,1,2,1,16',universityId:UniversityConfigs.defaultConfig.universityId,termWeeks:16,periodsPerDay:UniversityConfigs.defaultConfig.periodsPerDay).single.course!;
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
