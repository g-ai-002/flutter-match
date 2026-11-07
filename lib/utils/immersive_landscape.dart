import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 手机与折叠屏折叠态等窄屏设备：进入棋盘页时横屏全屏，把屏幕让给棋盘。
///
/// 平板、桌面与 Web 不改变方向与系统栏，避免突然旋转。
bool shouldImmersiveLandscape(Size size) =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android &&
    size.shortestSide < 600;

/// 棋盘页显示模式：满足 [shouldImmersiveLandscape] 时切到横屏并隐藏系统栏，
/// 离开后恢复系统栏与自动旋转。多个棋盘页叠放时按引用计数只在最后一个退出时恢复。
class BoardDisplayMode extends StatefulWidget {
  const BoardDisplayMode({super.key, required this.child});

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
    final wanted = shouldImmersiveLandscape(MediaQuery.sizeOf(context));
    if (wanted == _applied) return;
    _applied = wanted;
    if (wanted) {
      _holders++;
      if (_holders == 1) _enter();
    } else {
      _release();
    }
  }

  Future<void> _enter() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
