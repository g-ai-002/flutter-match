import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/pages/home_page.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/app_theme.dart';
import 'package:fortune_match/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const HomePage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('首页展示品牌、主行动与大入口', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(_wrap(settings));

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('开始闯关'), findsOneWidget);
    expect(find.text('第 1 关 · 初尝福味'), findsOneWidget);
    expect(find.text('关卡选择'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.textContaining('v${AppConstants.version}'), findsOneWidget);
  });

  testWidgets('宽屏下主视觉在左、行动区在右，无需滚动即可见', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));

    final title = tester.getCenter(find.text(AppConstants.appName).first);
    final start = tester.getRect(find.text('开始闯关'));
    expect(start.left, greaterThan(title.dx));
    expect(start.bottom, lessThan(900));
  });

  testWidgets('窄屏手机首页不溢出，关卡与设置入口改为上下堆叠', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));

    expect(tester.takeException(), isNull);
    final levels = tester.getRect(find.text('关卡选择'));
    final settings = tester.getRect(find.text('设置'));
    expect(settings.top, greaterThan(levels.bottom));
    expect(find.text('开始闯关'), findsOneWidget);
  });

  testWidgets('点击开始闯关进入第一关', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.tap(find.text('开始闯关'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('剩余步数'), findsOneWidget);
    expect(find.text('第 1 关 · 7 × 7'), findsOneWidget);
  });

  testWidgets('首页展示每日挑战入口并可进入今日棋局', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.pump();

    expect(find.text('每日挑战'), findsOneWidget);
    expect(find.text('去挑战'), findsOneWidget);

    await tester.tap(find.text('每日挑战'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('每日挑战 · 8 × 8'), findsOneWidget);
  });
}
