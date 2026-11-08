import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/match_game.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('向提示方向滑动即可完成交换', (tester) async {
    final controller = MatchController(level: kLevels.first, seed: 31);
    final game = MatchGame(
      controller: controller,
      darkMode: ValueNotifier(false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 480,
            height: 480,
            child: GameWidget(game: game),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    controller.requestHint();
    final hint = controller.hint!;
    final layout = game.board!.painter.layout;
    expect(layout.cell, greaterThan(20));

    final origin = tester.getTopLeft(find.byType(GameWidget<MatchGame>));
    final start = origin + layout.cellCenter(hint.a);
    final end = origin + layout.cellCenter(hint.b);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(end);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.movesLeft, kLevels.first.moves - 1);

    game.shutdown();
    controller.dispose();
    await tester.pump();
  });
}
