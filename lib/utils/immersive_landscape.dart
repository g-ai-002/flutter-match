import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 低于该高度时对局页改用紧凑留白。
const double kBoardCompactHeight = 560;

/// 棋盘上下对称留白：上方承载悬浮信息，下方承载控制按钮。
const double kBoardGap = 80;
const double kBoardGapCompact = 68;

/// 棋盘左右留白。
const double kBoardSidePadding = 4;

/// 对局页上下留白：屏幕越矮留白越小，棋盘始终位于中间。
double boardGapFor(double height) =>
    height < kBoardCompactHeight ? kBoardGapCompact : kBoardGap;

/// 棋盘区域里单个格子的边长，用于判断横竖屏哪种朝向更宽敞。
double _cellSize(Size screen, {required int cols, required int rows}) {
  final gap = boardGapFor(screen.height);
  final width = screen.width - kBoardSidePadding * 2;
  final height = screen.height - gap * 2;
  if (width <= 0 || height <= 0) return 0;
  return math.min(width / cols, height / rows);
}

/// 手机等窄屏设备是否该转成横屏全屏。
///
/// 只有横向棋盘（列数多于行数）在竖屏里受宽度限制、横屏能拿到更大的
/// 格子时才旋转；正方形或竖向棋盘保持竖屏，平板、桌面与 Web 也不改变方向。
bool shouldImmersiveLandscape(
  Size size, {
  required int cols,
  required int rows,
}) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  if (size.shortestSide >= 600) return false;
  if (size.width >= size.height) return false;
  final portrait = _cellSize(size, cols: cols, rows: rows);
  final landscape = _cellSize(size.flipped, cols: cols, rows: rows);
  return landscape > portrait;
}

/// 棋盘页显示模式：满足 [shouldImmersiveLandscape] 时切到横屏并隐藏系统栏，
/// 离开后恢复系统栏与自动旋转。多个棋盘页叠放时按引用计数只在最后一个退出时恢复。
class BoardDisplayMode extends StatefulWidget {
  const BoardDisplayMode({
    super.key,
    required this.cols,
    required this.rows,
    required this.child,
  });

  final int cols;
  final int rows;
  final Widget child;

  @override
  State<BoardDisplayMode> createState() => _BoardDisplayModeState();
}

class _BoardDisplayModeState extends State<BoardDisplayMode> {
  static int _holders = 0;

  bool _applied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只决定一次：旋转成功后的横屏尺寸不再满足竖屏条件，避免反复进出全屏。
    if (_applied) return;
    final wanted = shouldImmersiveLandscape(
      MediaQuery.sizeOf(context),
      cols: widget.cols,
      rows: widget.rows,
    );
    if (!wanted) return;
    _applied = true;
    _holders++;
    if (_holders == 1) _enter();
  }

  Future<void> _enter() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _release() {
    if (_holders > 0) _holders--;
    if (_holders > 0) return;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    if (_applied) _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
