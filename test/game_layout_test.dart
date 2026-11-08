import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/match_game.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/pages/game_page.dart';
import 'package:fortune_match/pages/widgets/prop_bar.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/app_theme.dart';
import 'package:fortune_match/utils/immersive_landscape.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Finder _boardFinder = find.byWidgetPredicate(
  (widget) => widget is GameWidget<MatchGame>,
);

Widget _wrap(SettingsProvider settings, {Level? level}) =>
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: buildLightTheme(),
        home: GamePage(level: level ?? kLevels.first),
      ),
    );

Future<void> _pumpPage(
  WidgetTester tester,
  Size size, {
  Level? level,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final storage = await StorageService.instance;
  await tester.pumpWidget(_wrap(SettingsProvider(storage), level: level));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('棋盘位于屏幕正中，信息在棋盘上方左右，按钮在下方', (tester) async {
    await _pumpPage(tester, const Size(1280, 900));

    final board = tester.getRect(_boardFinder);
    final gap = boardGapFor(900);
    expect(board.center.dx, closeTo(640, 0.5));
    expect(board.center.dy, closeTo(450, 0.5));
    expect(board.top, closeTo(gap, 0.5));

    final moves = tester.getRect(find.text('剩余步数'));
    expect(moves.bottom, lessThan(board.top), reason: '步数信息应悬浮在棋盘上方');
    final goal = tester.getRect(find.text('0/1200'));
    expect(goal.center.dx, greaterThan(board.center.dx), reason: '目标在右侧');
    final prop = tester.getRect(find.byType(PropButton).first);
    expect(prop.top, greaterThan(board.bottom), reason: '控制按钮应悬浮在棋盘下方');
  });

  testWidgets('操作提示悬浮在棋盘上方左侧，不遮挡棋盘', (tester) async {
    await _pumpPage(tester, const Size(1280, 900));

    await tester.tap(find.text('提示'));
    await tester.pump();

    final board = tester.getRect(_boardFinder);
    final prompt = tester.getRect(find.text('试试交换闪动的两枚棋子'));
    expect(prompt.bottom, lessThanOrEqualTo(board.top));
    expect(prompt.center.dx, lessThan(board.center.dx));

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('矮屏紧凑布局同样保持棋盘居中且提示不压棋盘', (tester) async {
    await _pumpPage(tester, const Size(844, 390));

    final board = tester.getRect(_boardFinder);
    expect(board.center.dx, closeTo(422, 0.5));
    expect(board.center.dy, closeTo(195, 0.5));
    expect(board.top, closeTo(kBoardGapCompact, 0.5));

    await tester.tap(find.byIcon(Icons.lightbulb_outline_rounded));
    await tester.pump();

    final prompt = tester.getRect(find.text('试试交换闪动的两枚棋子'));
    expect(prompt.bottom, lessThanOrEqualTo(board.top));
    final prop = tester.getRect(find.byType(PropButton).first);
    expect(prop.top, greaterThanOrEqualTo(board.bottom));

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('窄屏手机不溢出，棋盘仍位于正中', (tester) async {
    for (final size in const [Size(360, 640), Size(320, 568)]) {
      await _pumpPage(tester, size);
      final board = tester.getRect(_boardFinder);
      expect(board.center.dx, closeTo(size.width / 2, 0.5));
      expect(board.center.dy, closeTo(size.height / 2, 0.5));
    }
  });

  testWidgets('双目标关卡在窄屏上仍把目标排在棋盘上方右侧', (tester) async {
    await _pumpPage(tester, const Size(320, 568), level: levelById(3));

    final board = tester.getRect(_boardFinder);
    final goals = find.textContaining('/');
    expect(goals, findsNWidgets(2));
    for (final element in goals.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.center.dx, greaterThan(board.center.dx));
      expect(rect.bottom, lessThanOrEqualTo(board.top));
    }
  });

  testWidgets('离开对局页后停止引擎循环并拆除棋盘', (tester) async {
    await _pumpPage(tester, const Size(1280, 900));

    final game = tester.widget<GameWidget<MatchGame>>(_boardFinder).game!;
    expect(game.board, isNotNull);

    // 打开提示，制造计时器与逐帧刷新，验证离场时会一并清理。
    await tester.tap(find.text('提示'));
    await tester.pump();
    expect(game.board!.torndown, isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(game.board, isNull);
    expect(game.paused, isTrue);
  });
}
