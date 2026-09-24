import 'dart:convert';

import 'package:campus_mobile/features/study/agent_explorer.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('按智能体汇总不同课程的关联记录', (WidgetTester tester) async {
    final StudyWorkspace workspace = StudyWorkspace(
      activities: <StudyActivity>[
        StudyActivity(
          id: 'a1',
          course: '课程甲',
          title: '活动甲',
          objective: '',
          deadline: '',
        ),
        StudyActivity(
          id: 'a2',
          course: '课程乙',
          title: '活动乙',
          objective: '',
          deadline: '',
        ),
      ],
      sessions: <StudySession>[
        StudySession(
          id: 's1',
          activityId: 'a1',
          updatedAt: '',
          agentId: 'agent',
          question: '问题甲',
        ),
        StudySession(
          id: 's2',
          activityId: 'a2',
          updatedAt: '',
          agentId: 'agent',
          question: '问题乙',
        ),
      ],
      evidence: <StudyEvidence>[],
      knowledgeBases: <StudyKnowledgeBase>[],
      wikiEntries: <StudyWikiEntry>[],
      agents: <StudyAgent>[
        StudyAgent(
          id: 'agent',
          name: '资料助手',
          prompt: '',
          description: '跨课程整理',
          tools: <String>[],
          shared: false,
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          knowledgeBaseIds: <String>[],
        ),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStudyRepository.storageKey: jsonEncode(workspace.toJson()),
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AgentExplorer())),
    );
    await tester.pumpAndSettle();
    expect(find.text('关联记录 2 条'), findsNothing);
    expect(find.textContaining('关联记录 2 条'), findsOneWidget);
    await tester.tap(find.text('资料助手'));
    await tester.pumpAndSettle();
    expect(find.text('活动甲'), findsOneWidget);
    expect(find.text('活动乙'), findsOneWidget);
  });
}
