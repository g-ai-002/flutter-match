import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/pages/level_select_page.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const LevelSelectPage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'level_unlocked': 3,
      'stars_1': 3,
      'stars_2': 2,
      'best_1': 4200,
    });
    StorageService.resetForTests();
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('关卡列表按进度显示星级与上锁状态', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));

    expect(find.text('关卡选择'), findsOneWidget);
    expect(find.text('初尝福味'), findsOneWidget);
    expect(find.text('最高 4200 分'), findsOneWidget);
    expect(find.text('5 / 75'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(22));
  });

  testWidgets('点击已解锁关卡进入对局页', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.tap(find.text('灯笼高挂'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('剩余步数'), findsOneWidget);
    expect(find.text('第 2 关 · 7 × 7'), findsOneWidget);
  });
}
