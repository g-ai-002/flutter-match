import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/utils/system_ui.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('浅色底色配深色状态栏与导航栏图标', () {
    final style = systemOverlayStyleFor(const Color(0xFFFFFCF6));
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  test('深色底色配浅色状态栏与导航栏图标', () {
    final style = systemOverlayStyleFor(const Color(0xFF17140F));
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('Android 默认全屏沉浸，桌面端不改动系统栏', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    applyAppChrome();
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'SystemChrome.setEnabledSystemUIMode' &&
            call.arguments == 'SystemUiMode.immersiveSticky',
      ),
      isTrue,
      reason: 'Android 首页应隐藏系统栏，整屏沉浸',
    );

    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    applyAppChrome();
    await tester.pump();
    expect(calls, isEmpty, reason: '桌面窗口由系统管理，不切换系统栏模式');
  });
}
