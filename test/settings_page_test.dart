import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/pages/settings_page.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const SettingsPage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('设置页展示分组与动画速率选项', (tester) async {
    tester.view.physicalSize = const Size(820, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));

    expect(find.text('对局'), findsOneWidget);
    expect(find.text('音效与反馈'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('30 Hz 省电'), findsOneWidget);
    expect(find.text('60 Hz 均衡'), findsOneWidget);
    expect(find.text('120 Hz 顺滑'), findsOneWidget);
  });

  testWidgets('切换音效与动画速率写入本地存储', (tester) async {
    tester.view.physicalSize = const Size(820, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(_wrap(settings));

    await tester.tap(find.byKey(const ValueKey('switch-sound')));
    await tester.pump();
    expect(storage.soundEnabled, isFalse);

    await tester.tap(find.text('30 Hz 省电'));
    await tester.pump();
    expect(storage.logicRate.name, 'hz30');

    await tester.tap(find.byKey(const ValueKey('switch-dark')));
    await tester.pump();
    expect(storage.darkMode, isTrue);
  });

  testWidgets('主题皮肤按福星解锁并写入本地存储', (tester) async {
    tester.view.physicalSize = const Size(820, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(_wrap(settings));

    expect(find.text('主题皮肤'), findsOneWidget);
    expect(find.text('朱砂福韵'), findsOneWidget);
    expect(find.text('青瓷月白'), findsOneWidget);
    expect(find.text('墨玉灯影'), findsOneWidget);

    await tester.tap(find.text('青瓷月白'));
    await tester.pump();
    expect(storage.skin.name, 'cinnabar', reason: '福星不足时不能解锁');
    expect(find.textContaining('累计收集 30 颗福星'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
