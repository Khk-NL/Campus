import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 课程空间的数据边界；正式服务接入时替换本地实现。
abstract class StudyRepository {
  Future<StudyWorkspace> load();
  Future<void> save(StudyWorkspace workspace);
}

class LocalStudyRepository implements StudyRepository {
  LocalStudyRepository(this.preferences);
  static const String storageKey = 'campus.study.demo.v1';
  final SharedPreferences preferences;

  @override
  Future<StudyWorkspace> load() async {
    final String? raw = preferences.getString(storageKey);
    if (raw == null) return StudyWorkspace.demo();
    try {
      final StudyWorkspace workspace = StudyWorkspace.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // 早期演示课程更名时保留既有会话 id，不丢弃用户已经写下的记录。
      for (int index = 0; index < workspace.activities.length; index++) {
        final StudyActivity activity = workspace.activities[index];
        if (activity.id == 'demo-1' || activity.id == 'demo-2') {
          workspace.activities[index] = StudyActivity(
            id: activity.id,
            course: 'Campus 示例课程',
            title: activity.title,
            objective: activity.objective,
            deadline: activity.deadline,
            source: activity.source,
          );
        }
      }
      return workspace;
    } on FormatException {
      return StudyWorkspace.demo();
    } on TypeError {
      return StudyWorkspace.demo();
    }
  }

  @override
  Future<void> save(StudyWorkspace workspace) async {
    if (!await preferences.setString(
      storageKey,
      jsonEncode(workspace.toJson()),
    )) {
      throw StateError('本地演示数据保存失败');
    }
  }
}

/// 演示数据与真实课程隔离：所有初始活动均明确标注“演示”。
class StudyWorkspace {
  StudyWorkspace({
    required this.activities,
    required this.sessions,
    required this.evidence,
    required this.knowledgeBases,
    required this.wikiEntries,
    required this.agents,
  });

  final List<StudyActivity> activities;
  final List<StudySession> sessions;
  final List<StudyEvidence> evidence;
  final List<StudyKnowledgeBase> knowledgeBases;
  final List<StudyWikiEntry> wikiEntries;
  final List<StudyAgent> agents;

  factory StudyWorkspace.demo() => StudyWorkspace(
    activities: <StudyActivity>[
      StudyActivity(
        id: 'demo-1',
        course: 'Campus 示例课程',
        title: '校园服务需求观察',
        objective: '提出一个真实问题，记录两条可核查证据，并形成可修订的结论。',
        deadline: '本周内',
      ),
      StudyActivity(
        id: 'demo-2',
        course: 'Campus 示例课程',
        title: '资料对照与观点形成',
        objective: '比较不同资料的观点，标明来源与尚未解决的问题。',
        deadline: '下周内',
      ),
    ],
    sessions: <StudySession>[],
    evidence: <StudyEvidence>[],
    knowledgeBases: <StudyKnowledgeBase>[],
    wikiEntries: <StudyWikiEntry>[],
    agents: <StudyAgent>[],
  );

  factory StudyWorkspace.fromJson(Map<String, dynamic> json) => StudyWorkspace(
    activities: _objects(json['activities'])
        .map(StudyActivity.fromJson)
        .toList(),
    sessions: _objects(json['sessions']).map(StudySession.fromJson).toList(),
    evidence: _objects(json['evidence']).map(StudyEvidence.fromJson).toList(),
    knowledgeBases: _objects(json['knowledgeBases'])
        .map(StudyKnowledgeBase.fromJson)
        .toList(),
    wikiEntries: _objects(json['wikiEntries'])
        .map(StudyWikiEntry.fromJson)
        .toList(),
    agents: _objects(json['agents']).map(StudyAgent.fromJson).toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'activities': activities.map((StudyActivity x) => x.toJson()).toList(),
    'sessions': sessions.map((StudySession x) => x.toJson()).toList(),
    'evidence': evidence.map((StudyEvidence x) => x.toJson()).toList(),
    'knowledgeBases': knowledgeBases
        .map((StudyKnowledgeBase x) => x.toJson())
        .toList(),
    'wikiEntries': wikiEntries.map((StudyWikiEntry x) => x.toJson()).toList(),
    'agents': agents.map((StudyAgent x) => x.toJson()).toList(),
  };
}

List<Map<String, dynamic>> _objects(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((Map x) => Map<String, dynamic>.from(x))
          .toList()
    : <Map<String, dynamic>>[];

class StudyActivity {
  StudyActivity({
    required this.id,
    required this.course,
    required this.title,
    required this.objective,
    required this.deadline,
    this.source = 'demo',
    this.courseId,
  });
  final String id, course, title, objective, deadline, source;
  final String? courseId;
  factory StudyActivity.fromJson(Map<String, dynamic> j) => StudyActivity(
    id: j['id'] as String? ?? '',
    course: j['course'] as String? ?? '',
    title: j['title'] as String? ?? '',
    objective: j['objective'] as String? ?? '',
    deadline: j['deadline'] as String? ?? '',
    source: j['source'] as String? ?? 'demo',
    courseId: j['courseId'] as String?,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'course': course,
    'title': title,
    'objective': objective,
    'deadline': deadline,
    'source': source,
    'courseId': courseId,
  };
}

class StudySession {
  StudySession({
    required this.id,
    required this.activityId,
    required this.updatedAt,
    this.question = '',
    this.notes = '',
    this.conclusion = '',
    this.openQuestions = '',
    this.feedback = '',
    this.agentId,
    this.knowledgeBaseId,
    this.referenceMode = 'rag',
    this.wikiEntryId,
  });
  final String id, activityId;
  String updatedAt, question, notes, conclusion, openQuestions, feedback;
  String? agentId, knowledgeBaseId;
  String referenceMode;
  String? wikiEntryId;
  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
    id: j['id'] as String? ?? '',
    activityId: j['activityId'] as String? ?? '',
    updatedAt: j['updatedAt'] as String? ?? '',
    question: j['question'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    conclusion: j['conclusion'] as String? ?? '',
    openQuestions: j['openQuestions'] as String? ?? '',
    feedback: j['feedback'] as String? ?? '',
    agentId: j['agentId'] as String?,
    knowledgeBaseId: j['knowledgeBaseId'] as String?,
    referenceMode: j['referenceMode'] as String? ?? 'rag',
    wikiEntryId: j['wikiEntryId'] as String?,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'activityId': activityId,
    'updatedAt': updatedAt,
    'question': question,
    'notes': notes,
    'conclusion': conclusion,
    'openQuestions': openQuestions,
    'feedback': feedback,
    'agentId': agentId,
    'knowledgeBaseId': knowledgeBaseId,
    'referenceMode': referenceMode,
    'wikiEntryId': wikiEntryId,
  };
}

class StudyEvidence {
  StudyEvidence({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.url,
    required this.note,
  });
  final String id, sessionId, title, url, note;
  factory StudyEvidence.fromJson(Map<String, dynamic> j) => StudyEvidence(
    id: j['id'] as String? ?? '',
    sessionId: j['sessionId'] as String? ?? '',
    title: j['title'] as String? ?? '',
    url: j['url'] as String? ?? '',
    note: j['note'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sessionId': sessionId,
    'title': title,
    'url': url,
    'note': note,
  };
}

class StudyKnowledgeBase {
  StudyKnowledgeBase({required this.id, required this.name, this.courseId});
  final String id, name;
  final String? courseId;
  factory StudyKnowledgeBase.fromJson(Map<String, dynamic> j) =>
      StudyKnowledgeBase(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        courseId: j['courseId'] as String?,
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'courseId': courseId,
  };
}

class StudyWikiEntry {
  StudyWikiEntry({
    required this.id,
    required this.topic,
    required this.title,
    required this.tags,
    required this.content,
    this.courseId,
  });
  final String id, topic, title, tags, content;
  final String? courseId;
  factory StudyWikiEntry.fromJson(Map<String, dynamic> j) => StudyWikiEntry(
    id: j['id'] as String? ?? '',
    topic: j['topic'] as String? ?? '',
    title: j['title'] as String? ?? '',
    tags: j['tags'] as String? ?? '',
    content: j['content'] as String? ?? '',
    courseId: j['courseId'] as String?,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'topic': topic,
    'title': title,
    'tags': tags,
    'content': content,
    'courseId': courseId,
  };
}

class StudyAgent {
  StudyAgent({
    required this.id,
    required this.name,
    required this.prompt,
    required this.description,
    required this.tools,
    required this.shared,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.knowledgeBaseIds,
    this.courseId,
  });
  final String id, name, prompt, description;
  final List<String> tools;
  final bool shared;
  final double temperature;
  final double topP;
  final int topK;
  final List<String> knowledgeBaseIds;
  final String? courseId;
  factory StudyAgent.fromJson(Map<String, dynamic> j) => StudyAgent(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    prompt: j['prompt'] as String? ?? '',
    description: j['description'] as String? ?? '',
    tools: (j['tools'] as List<dynamic>? ?? <dynamic>[])
        .whereType<String>()
        .toList(),
    shared: j['shared'] as bool? ?? false,
    temperature: (j['temperature'] as num?)?.toDouble() ?? 0.7,
    topP: (j['topP'] as num?)?.toDouble() ?? 0.9,
    topK: (j['topK'] as num?)?.toInt() ?? 40,
    knowledgeBaseIds: (j['knowledgeBaseIds'] as List<dynamic>? ?? <dynamic>[])
        .whereType<String>()
        .toList(),
    courseId: j['courseId'] as String?,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'prompt': prompt,
    'description': description,
    'tools': tools,
    'shared': shared,
    'temperature': temperature,
    'topP': topP,
    'topK': topK,
    'knowledgeBaseIds': knowledgeBaseIds,
    'courseId': courseId,
  };
}
