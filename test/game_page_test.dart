import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/props.dart';
import 'package:fortune_match/pages/game_page.dart';
import 'package:fortune_match/pages/widgets/prop_bar.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(
    theme: buildLightTheme(),
    home: GamePage(level: kLevels.first),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('对局页展示悬浮 HUD、目标与工具条', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('第 1 关 · 7 × 7'), findsOneWidget);
    expect(find.text('初尝福味'), findsOneWidget);
    expect(find.text('剩余步数'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('提示'), findsOneWidget);
    expect(find.text('重开'), findsOneWidget);
    expect(find.byType(PropButton), findsNWidgets(3));
    expect(find.text('0/1200'), findsOneWidget);
  });

  testWidgets('提示按钮给出可交换位置，重开需二次确认', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.pump();

    await tester.tap(find.text('提示'));
    await tester.pump();
    expect(find.text('试试交换闪动的两枚棋子'), findsOneWidget);

    await tester.tap(find.text('重开'));
    await tester.pump();
    expect(find.text('重开本关？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();

    // 清掉提示计时器，避免测试结束时仍有挂起任务。
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('道具按钮可进入待命状态，再次点击取消', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.gavel_rounded));
    await tester.pump();
    expect(find.text('点击一枚棋子，用小锤敲掉它'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.gavel_rounded));
    await tester.pump();
    expect(find.text('点击一枚棋子，用小锤敲掉它'), findsNothing);
  });

  testWidgets('道具用尽后点击打开道具铺', (tester) async {
    SharedPreferences.setMockInitialValues({'prop_hammer': 0});
    StorageService.resetForTests();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    await tester.pumpWidget(_wrap(SettingsProvider(storage)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.gavel_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('道具铺'), findsOneWidget);
    expect(find.text('福币不足'), findsWidgets);
  });

  testWidgets('道具铺购买后库存同步到底部工具条并写入本地存储', (tester) async {
    SharedPreferences.setMockInitialValues({
      'prop_hammer': 0,
      'prop_swap': 0,
      'prop_shuffle': 0,
      'fortune_coins': 100,
    });
    StorageService.resetForTests();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(_wrap(settings));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.gavel_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('道具铺'), findsOneWidget);

    await tester.tap(find.text('${PropKind.hammer.price} 福币'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已有 1'), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);
    expect(settings.coins, 100 - PropKind.hammer.price);
    expect(settings.propCount(PropKind.hammer), 1);
  });
}
