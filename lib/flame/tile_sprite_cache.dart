import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../theme/tile_art.dart';

/// 棋子与冰层的贴图缓存：按格子尺寸缓存 Picture，尺寸变化时才重绘。
///
/// 贴图按「类型 × 特殊棋子」存进定长数组，绘制热路径是一次带界检查的
/// 下标访问，没有哈希与字符串拼接；启动后还会在空闲帧分批预录，
/// 避免第一次消除才临时录制造成掉帧。
class TileSpriteCache {
  static const int _specialCount = 5;
  static final int _tileSlots = TileType.values.length * _specialCount;
  static const int _iceSlots = 4;

  final TileGlyphCache _glyphs = TileGlyphCache();
  final List<Picture?> _tiles = List<Picture?>.filled(_tileSlots, null);
  final List<Picture?> _ice = List<Picture?>.filled(_iceSlots, null);
  int _cellKey = 0;

  int _warmKey = -1;
  int _warmCursor = 0;

  /// 每帧开始时同步一次格子尺寸，随后的取图不必重复换算。
  void beginFrame(double cell) => _syncCell(cell);

  /// 某类棋子的贴图，[cell] 为当前格子边长。
  Picture tile(TileType type, SpecialType special, double cell) {
    _syncCell(cell);
    final key = type.index * _specialCount + special.index;
    final cached = _tiles[key];
    if (cached != null) return cached;
    final picture = _recordTile(type, special, cell);
    _tiles[key] = picture;
    return picture;
  }

  /// 某层数冰面的贴图，[cell] 为当前格子边长。
  Picture ice(int layers, double cell) {
    _syncCell(cell);
    if (layers >= 0 && layers < _iceSlots) {
      final cached = _ice[layers];
      if (cached != null) return cached;
      final picture = _recordIce(layers, cell);
      _ice[layers] = picture;
      return picture;
    }
    return _recordIce(layers, cell);
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
      _tiles[key] = _recordTile(type, special, cell);
      built++;
    }
    return _warmCursor >= _tileSlots;
  }

  Picture _recordTile(TileType type, SpecialType special, double cell) {
    final recorder = PictureRecorder();
    paintTile(
      Canvas(recorder),
      Rect.fromLTWH(0, 0, cell, cell),
      type,
      special,
      _glyphs,
    );
    return recorder.endRecording();
  }

  Picture _recordIce(int layers, double cell) {
    final recorder = PictureRecorder();
    paintIce(Canvas(recorder), Rect.fromLTWH(0, 0, cell, cell), layers);
    return recorder.endRecording();
  }

  /// 格子尺寸变化超过 1/4 像素时重建全部贴图与文字排版。
  void _syncCell(double cell) {
    final key = (cell * 4).round();
    if (key == _cellKey) return;
    _disposePictures();
    _cellKey = key;
  }

  /// 丢弃全部贴图但保留当前格子尺寸，下一次取图时按新字体状态重录。
  void invalidate() {
    _disposePictures();
    _glyphs.clear();
    _warmKey = -1;
    _warmCursor = 0;
  }

  void _disposePictures() {
    for (final picture in _tiles) {
      picture?.dispose();
    }
    for (final picture in _ice) {
      picture?.dispose();
    }
    _tiles.fillRange(0, _tileSlots, null);
    _ice.fillRange(0, _iceSlots, null);
  }

  void dispose() {
    invalidate();
    _cellKey = 0;
  }
}
