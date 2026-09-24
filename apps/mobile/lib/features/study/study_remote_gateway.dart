import 'dart:typed_data';

import 'package:campus_mobile/features/study/study_repository.dart';

/// 远程能力端口。当前没有实现；不得用本地假结果冒充服务端响应。
/// 鉴权由未来的服务端会话承担，Flutter 客户端不保存学校平台密钥。
abstract class StudyRemoteGateway {
  Future<List<StudyActivity>> listActivities(String courseId);
  Future<List<StudySession>> listSessions(String activityId);
  Future<StudySession> upsertSession(StudySession session);
  Future<List<StudyEvidence>> listEvidence(String sessionId);
  Future<StudyEvidence> addEvidence(StudyEvidence evidence);
  Future<List<StudyKnowledgeBase>> listKnowledgeBases();
  Future<StudyKnowledgeBase> createKnowledgeBase(String name);
  Future<StudyDocument> uploadDocument({
    required String knowledgeBaseId,
    required String fileName,
    required Uint8List bytes,
  });
  Future<List<StudyWikiEntry>> listWikiEntries({String? topic, String? query});
  Future<StudyWikiEntry> upsertWikiEntry(StudyWikiEntry entry);
  Future<List<StudyAgent>> listAgents();
  Future<StudyAnswer> askAssistant({
    required String sessionId,
    required String prompt,
    String? agentId,
    String? knowledgeBaseId,
    String? wikiEntryId,
    required String referenceMode,
    required bool strictCitation,
  });
  Future<StudyAgent> saveAgent(StudyAgent agent);
  Future<StudyShare> shareSession(String sessionId);
  Future<StudyAssessment> fetchAssessment(String sessionId);
}

class StudyDocument {
  const StudyDocument({
    required this.id,
    required this.name,
    required this.status,
  });
  final String id, name, status;
}

class StudyAnswer {
  const StudyAnswer({required this.text, required this.citations});
  final String text;
  final List<StudyCitation> citations;
}

class StudyCitation {
  const StudyCitation({
    required this.title,
    required this.url,
    required this.excerpt,
  });
  final String title, url, excerpt;
}

class StudyShare {
  const StudyShare({required this.url, required this.expiresAt});
  final Uri url;
  final DateTime expiresAt;
}

class StudyAssessment {
  const StudyAssessment({
    required this.sessionId,
    required this.feedback,
    required this.evidenceIds,
  });
  final String sessionId, feedback;
  final List<String> evidenceIds;
}
