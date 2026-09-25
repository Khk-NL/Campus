import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/features/study/eduwork_gateway_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('默认未配置，不会暗示 EduWork 已接入', () {
    expect(AppConfig.defaults().hasEduWorkGateway, isFalse);
  });

  test('只接受 Campus 网关契约并传递普通用户令牌', () async {
    final MockClient client = MockClient((http.Request request) async {
      expect(request.url.toString(), 'https://school.example/campus/v1/status');
      expect(request.headers['authorization'], 'Bearer pilot-token');
      return http.Response(
        '{"contract":"campus-eduwork-gateway/v1","ready":true,'
        '"eduworkRevision":"68eb286","capabilities":["quiz","flashcards"]}',
        200,
      );
    });
    final EduWorkGatewayStatus status = await EduWorkGatewayProbe(
      baseUrl: 'https://school.example/campus/',
      client: client,
    ).check(pocketBaseToken: 'pilot-token');
    expect(status.ready, isTrue);
    expect(status.capabilityIds, <String>{'quiz', 'flashcards'});
  });

  test('EduWork 桌面服务或错误契约不能冒充 Campus 网关', () async {
    final EduWorkGatewayProbe probe = EduWorkGatewayProbe(
      baseUrl: 'https://school.example',
      client: MockClient((_) async => http.Response('{"ready":true}', 200)),
    );
    await expectLater(probe.check(), throwsFormatException);
    expect(
      () => EduWorkGatewayProbe(baseUrl: 'http://public.example').statusUri,
      throwsFormatException,
    );
    expect(
      () =>
          EduWorkGatewayProbe(baseUrl: 'https://user:secret@school.example')
              .statusUri,
      throwsFormatException,
    );
  });
}
