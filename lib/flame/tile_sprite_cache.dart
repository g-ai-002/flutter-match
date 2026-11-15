import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../models/tile.dart';
import '../theme/tile_art.dart';

/// 棋子与冰层的贴图缓存：按格子尺寸把图案预录成位图，绘制时只做一次贴图。
///
/// 棋子底纹含渐变、描边与文字，若逐帧重放绘制指令，每枚棋子都要重新光栅化；
/// 预录成 [ui.Image] 后每帧只是一次缩放贴图，淡出也能用画笔透明度完成，
/// 不再为每枚棋子开一次 saveLayer。位图按设备像素比放大录制，高分屏不糊。
class TileSpriteCache {
  static const int _specialCount = 5;
  static final int _tileSlots = TileType.values.length * _specialCount;
  static const int _iceSlots = 4;

  /// 位图录制倍率上限，兼顾高分屏清晰度与显存占用。
  static const double _maxPixelRatio = 3;

  final TileGlyphCache _glyphs = TileGlyphCache();
  final List<ui.Image?> _tiles = List<ui.Image?>.filled(_tileSlots, null);
  final List<ui.Image?> _ice = List<ui.Image?>.filled(_iceSlots, null);

  int _cellKey = 0;
  double _lastCell = 0;
  double _lastRatio = 0;
  double _ratio = 1;
  int _side = 0;
  Rect _source = Rect.zero;
  int _generation = 0;

  int _warmKey = -1;
  int _warmCursor = 0;

  /// 位图全尺寸的源矩形，绘制时与目标格子矩形配对使用。
  Rect get sourceRect => _source;

  /// 贴图代次：位图被丢弃后自增，绘制方据此丢弃引用旧位图的缓存画面。
  int get generation => _generation;

  /// 位图录制次数，供性能测试断言贴图只在尺寸变化时重建。
  @visibleForTesting
  int rasterizations = 0;

  /// 每帧开始时同步一次格子尺寸，随后的取图不必重复换算。
  void beginFrame(double cell) => _syncCell(cell);

  /// 某类棋子的贴图，[cell] 为当前格子边长。
  ui.Image tile(TileType type, SpecialType special, double cell) {
    _syncCell(cell);
    final key = type.index * _specialCount + special.index;
    final cached = _tiles[key];
    if (cached != null) return cached;
    final image = _rasterize(
      (canvas) => paintTile(
        canvas,
        Rect.fromLTWH(0, 0, cell, cell),
        type,
        special,
        _glyphs,
      ),
      cell,
    );
    _tiles[key] = image;
    return image;
  }

  /// 某层数冰面的贴图，[cell] 为当前格子边长。
  ui.Image ice(int layers, double cell) {
    _syncCell(cell);
    if (layers >= 0 && layers < _iceSlots) {
      final cached = _ice[layers];
      if (cached != null) return cached;
      final image = _rasterize(
        (canvas) => paintIce(canvas, Rect.fromLTWH(0, 0, cell, cell), layers),
        cell,
      );
      _ice[layers] = image;
      return image;
    }
    return _rasterize(
      (canvas) => paintIce(canvas, Rect.fromLTWH(0, 0, cell, cell), layers),
      cell,
    );
  }

  /// 当前格子尺寸下是否还有贴图没预录。
  bool get warmupPending => _warmKey != _cellKey || _warmCursor < _tileSlots;

  /// 在空闲帧分批预录棋子贴图，返回是否已经全部就绪。
  bool warmupStep(double cell, {int budget = 4}) {
    _syncCell(cell);
    if (_warmKey != _cellKey) {
      _warmKey = _cellKey;
      _warmCursor = 0;
    }
    var built = 0;
    while (_warmCursor < _tileSlots && built < budget) {
      final key = _warmCursor++;
      if (_tiles[key] != null) continue;
      final type = TileType.values[key ~/ _specialCount];
      final special = SpecialType.values[key % _specialCount];
      _tiles[key] = _rasterize(
        (canvas) => paintTile(
          canvas,
          Rect.fromLTWH(0, 0, cell, cell),
          type,
          special,
          _glyphs,
        ),
        cell,
      );
      built++;
    }
    return _warmCursor >= _tileSlots;
  }

  /// 把一段绘制录成位图：按整数像素边长录制，绘制时再缩回逻辑尺寸。
  ///
  /// 边长取当前缓存代的 [_side]，同一代的所有贴图与 [sourceRect] 严格对应；
  /// 随后的 1/4 像素内尺寸抖动不会让源矩形与位图错位。
  ui.Image _rasterize(void Function(Canvas canvas) draw, double cell) {
    final side = _side.clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(side / cell);
    draw(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(side, side);
    picture.dispose();
    rasterizations++;
    return image;
  }

  /// 格子尺寸或像素比变化时重建全部位图与文字排版。
  ///
  /// 逐枚取图都会走到这里，先做一次 double 比较，尺寸没变时不再换算量化键。
  void _syncCell(double cell) {
    final ratio = _pixelRatio();
    if (cell == _lastCell && ratio == _lastRatio) return;
    _lastCell = cell;
    _lastRatio = ratio;
    final key = (cell * 4).round();
    if (key == _cellKey && ratio == _ratio) return;
    _disposePictures();
    _cellKey = key;
    _ratio = ratio;
    _side = (cell * ratio).round().clamp(1, 4096);
    _source = Rect.fromLTWH(0, 0, _side.toDouble(), _side.toDouble());
  }

  static double _pixelRatio() {
    final view = ui.PlatformDispatcher.instance.implicitView;
    final ratio = view?.devicePixelRatio ?? 1;
    return ratio.clamp(1.0, _maxPixelRatio);
  }

  /// 丢弃全部位图但保留当前格子尺寸，下一次取图时按新字体状态重录。
  void invalidate() {
    _disposePictures();
    _glyphs.clear();
    _warmKey = -1;
    _warmCursor = 0;
  }

  void _disposePictures() {
    for (final image in _tiles) {
      image?.dispose();
    }
    for (final image in _ice) {
      image?.dispose();
    }
    _tiles.fillRange(0, _tileSlots, null);
    _ice.fillRange(0, _iceSlots, null);
    _generation++;
  }

  void dispose() {
    invalidate();
    _cellKey = 0;
    _lastCell = 0;
    _lastRatio = 0;
    _side = 0;
    _source = Rect.zero;
  }
}
