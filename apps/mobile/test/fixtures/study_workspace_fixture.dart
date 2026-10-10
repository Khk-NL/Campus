import 'package:campus_mobile/features/study/study_repository.dart';

StudyWorkspace buildStudyWorkspaceFixture() => StudyWorkspace(
  activities: <StudyActivity>[
    StudyActivity(
      id: 'demo-1',
      course: 'Campulse 示例课程',
      title: '校园服务需求观察',
      objective: '提出一个真实问题，记录两条可核查证据，并形成可修订的结论。',
      deadline: '本周内',
    ),
    StudyActivity(
      id: 'demo-2',
      course: 'Campulse 示例课程',
      title: '资料对照与观点形成',
      objective: '比较不同资料的观点，标明来源与待解决的问题。',
      deadline: '下周内',
    ),
  ],
  sessions: [],
  evidence: [],
  knowledgeBases: [],
  wikiEntries: [],
  agents: [],
);
