import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/pages/achievements_page.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const AchievementsPage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('成就页展示全部成就与解锁进度', (tester) async {
    tester.view.physicalSize = const Size(820, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));

    expect(find.text('0 / 13'), findsOneWidget);
    expect(find.text('初入福门'), findsOneWidget);
    expect(find.text('福运满堂'), findsOneWidget);
    expect(find.text('连锁高手'), findsOneWidget);
    expect(find.text('已解锁'), findsNothing);
  });

  testWidgets('已有进度时显示已解锁标记与读数', (tester) async {
    SharedPreferences.setMockInitialValues({
      'stars_1': 3,
      'stars_2': 3,
      'level_unlocked': 3,
    });
    StorageService.resetForTests();
    tester.view.physicalSize = const Size(820, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));

    expect(find.text('2 / 13'), findsOneWidget);
    expect(find.text('已解锁'), findsWidgets);
    expect(find.text('2 / 10'), findsWidgets);
  });
}
