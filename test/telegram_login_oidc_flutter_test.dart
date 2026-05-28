import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_login_oidc_flutter/telegram_login_oidc_flutter.dart';
import 'package:telegram_login_oidc_flutter/telegram_login_oidc_flutter_platform_interface.dart';
import 'package:telegram_login_oidc_flutter/telegram_login_oidc_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTelegramLoginFlutterPlatform
    with MockPlatformInterfaceMixin
    implements TelegramLoginFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TelegramLoginFlutterPlatform initialPlatform = TelegramLoginFlutterPlatform.instance;

  test('$MethodChannelTelegramLoginFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTelegramLoginFlutter>());
  });

  test('getPlatformVersion', () async {
    TelegramLoginFlutter telegramLoginFlutterPlugin = TelegramLoginFlutter();
    MockTelegramLoginFlutterPlatform fakePlatform = MockTelegramLoginFlutterPlatform();
    TelegramLoginFlutterPlatform.instance = fakePlatform;

    expect(await telegramLoginFlutterPlugin.getPlatformVersion(), '42');
  });
}
