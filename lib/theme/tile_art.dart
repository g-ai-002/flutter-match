import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tile.dart';

/// 单种棋子的配色：高光、主色、暗部与纹样颜色。
class TilePalette {
  const TilePalette({
    required this.light,
    required this.base,
    required this.deep,
    required this.glyph,
  });

  final Color light;
  final Color base;
  final Color deep;
  final Color glyph;
}

const Map<TileType, TilePalette> kTilePalettes = {
  TileType.coin: TilePalette(
    light: Color(0xFFF8DF9C),
    base: Color(0xFFE7B24B),
    deep: Color(0xFF9A6413),
    glyph: Color(0xFF6B3A06),
  ),
  TileType.ingot: TilePalette(
    light: Color(0xFFF6B08C),
    base: Color(0xFFDC6B45),
    deep: Color(0xFF8C3418),
    glyph: Color(0xFF5C1E08),
  ),
  TileType.lantern: TilePalette(
    light: Color(0xFFF3A29E),
    base: Color(0xFFD6534B),
    deep: Color(0xFF8A221C),
    glyph: Color(0xFF5A0F0B),
  ),
  TileType.jade: TilePalette(
    light: Color(0xFFA8D6B8),
    base: Color(0xFF5FA377),
    deep: Color(0xFF2C6347),
    glyph: Color(0xFF14402C),
  ),
  TileType.porcelain: TilePalette(
    light: Color(0xFFA9CDEA),
    base: Color(0xFF4F86B5),
    deep: Color(0xFF24537C),
    glyph: Color(0xFF103651),
  ),
  TileType.lotus: TilePalette(
    light: Color(0xFFCBADE3),
    base: Color(0xFF9B6BB5),
    deep: Color(0xFF5F3A80),
    glyph: Color(0xFF3A1F58),
  ),
};

/// 棋子文字缓存：同一尺寸与颜色的纹样只排版一次。
class TileGlyphCache {
  final Map<String, TextPainter> _painters = {};

  TextPainter painter(
    String text,
    double fontSize,
    Color color, {
    FontWeight weight = FontWeight.w700,
  }) {
    final key = '$text|${fontSize.toStringAsFixed(2)}|'
        '${color.toARGB32()}|${weight.value}';
    return _painters.putIfAbsent(key, () {
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            color: color,
            fontWeight: weight,
            shadows: const [
              Shadow(color: Color(0x33000000), offset: Offset(0, 1), blurRadius: 1),
            ],
          ),
        ),
      );
      painter.layout();
      return painter;
    });
  }

  void clear() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

/// 绘制一枚棋子（普通棋子、特殊棋子共用同一套底纹）。
void paintTile(
  Canvas canvas,
  Rect rect,
  TileType type,
  SpecialType special,
  TileGlyphCache cache, {
  double opacity = 1,
  double glow = 0,
  Color glowColor = const Color(0xFFFFE0A3),
}) {
  if (opacity <= 0.01) return;
  final palette = kTilePalettes[type]!;
  final inset = rect.deflate(rect.width * 0.045);
  final radius = Radius.circular(inset.width * 0.26);
  final body = RRect.fromRectAndRadius(inset, radius);
  final layered = opacity < 0.999;
  if (layered) {
    canvas.saveLayer(
      rect.inflate(4),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  if (glow > 0) {
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.55 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, inset.width * 0.12);
    canvas.drawRRect(body.inflate(inset.width * 0.05), glowPaint);
  }

  canvas.drawRRect(
    body.shift(Offset(0, inset.height * 0.07)),
    Paint()..color = const Color(0x2E000000),
  );

  final shader = special == SpecialType.rainbow
      ? SweepGradient(
          colors: [
            for (final item in kTilePalettes.values) item.base,
            kTilePalettes.values.first.base,
          ],
        ).createShader(inset)
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.light, palette.base, palette.deep],
          stops: const [0, 0.62, 1],
        ).createShader(inset);
  canvas.drawRRect(body, Paint()..shader = shader);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset.left + inset.width * 0.14,
        inset.top + inset.height * 0.1,
        inset.width * 0.72,
        inset.height * 0.28,
      ),
      Radius.circular(inset.width * 0.16),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.28),
  );

  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = inset.width * 0.045
      ..color = (special == SpecialType.rainbow ? Colors.white : palette.deep)
          .withValues(alpha: 0.8),
  );

  final glyph = special == SpecialType.rainbow ? '福' : type.glyph;
  final glyphPainter = cache.painter(
    glyph,
    inset.width * 0.46,
    special == SpecialType.rainbow
        ? Colors.white
        : palette.glyph.withValues(alpha: 0.92),
  );
  glyphPainter.paint(
    canvas,
    Offset(
      inset.center.dx - glyphPainter.width / 2,
      inset.center.dy - glyphPainter.height / 2 + inset.height * 0.01,
    ),
  );

  switch (special) {
    case SpecialType.row:
      _paintArrows(canvas, inset, horizontal: true);
    case SpecialType.column:
      _paintArrows(canvas, inset, horizontal: false);
    case SpecialType.bomb:
      _paintBombMark(canvas, inset);
    case SpecialType.rainbow:
      _paintRainbowSparkles(canvas, inset);
    case SpecialType.none:
      break;
  }

  if (layered) canvas.restore();
}

void _paintArrows(Canvas canvas, Rect rect, {required bool horizontal}) {
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..style = PaintingStyle.stroke
    ..strokeWidth = rect.width * 0.055
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final size = rect.width * 0.085;
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  for (var i = 0; i < 2; i++) {
    final offset = rect.width * (0.13 + i * 0.1);
    if (horizontal) {
      _chevron(canvas, Offset(rect.left + offset, cy), size, false, paint);
      _chevron(canvas, Offset(rect.right - offset, cy), size, true, paint);
    } else {
      _chevron(canvas, Offset(cx, rect.top + offset), size, true, paint, vertical: true);
      _chevron(canvas, Offset(cx, rect.bottom - offset), size, false, paint, vertical: true);
    }
  }
}

/// 画一个指向左/右（或上/下）的箭头。
void _chevron(
  Canvas canvas,
  Offset tip,
  double size,
  bool pointRight,
  Paint paint, {
  bool vertical = false,
}) {
  final path = Path();
  if (vertical) {
    final dy = pointRight ? size : -size;
    path
      ..moveTo(tip.dx - size * 0.75, tip.dy - dy * 0.75)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + size * 0.75, tip.dy - dy * 0.75);
  } else {
    final dx = pointRight ? size : -size;
    path
      ..moveTo(tip.dx - dx * 0.75, tip.dy - size * 0.75)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - dx * 0.75, tip.dy + size * 0.75);
  }
  canvas.drawPath(path, paint);
}

void _paintBombMark(Canvas canvas, Rect rect) {
  final center = rect.center;
  final radius = rect.width * 0.36;
  final dot = Paint()..color = Colors.white.withValues(alpha: 0.85);
  for (var i = 0; i < 8; i++) {
    final angle = math.pi * 2 * i / 8 + math.pi / 8;
    final position = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    canvas.drawCircle(position, rect.width * 0.032, dot);
  }
  canvas.drawCircle(
    center,
    radius * 0.94,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.width * 0.045
      ..color = Colors.white.withValues(alpha: 0.9),
  );
}

void _paintRainbowSparkles(Canvas canvas, Rect rect) {
  final paint = Paint()..color = Colors.white.withValues(alpha: 0.95);
  for (final (dx, dy, r) in const [
    (-0.3, -0.32, 0.045),
    (0.32, -0.24, 0.035),
    (0.28, 0.3, 0.04),
    (-0.26, 0.28, 0.03),
  ]) {
    canvas.drawCircle(
      Offset(
        rect.center.dx + rect.width * dx,
        rect.center.dy + rect.height * dy,
      ),
      rect.width * r,
      paint,
    );
  }
}

/// 冰层覆盖：两层为厚冰，一层为裂冰。
void paintIce(Canvas canvas, Rect rect, int layers) {
  if (layers <= 0) return;
  final inset = rect.deflate(rect.width * 0.045);
  final body = RRect.fromRectAndRadius(
    inset,
    Radius.circular(inset.width * 0.26),
  );
  final alpha = layers >= 2 ? 0.5 : 0.3;
  canvas.drawRRect(
    body,
    Paint()..color = const Color(0xFFBFE3F2).withValues(alpha: alpha),
  );
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = inset.width * 0.05
      ..color = Colors.white.withValues(alpha: 0.72),
  );
  final crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = inset.width * 0.028
    ..color = Colors.white.withValues(alpha: 0.85)
    ..strokeCap = StrokeCap.round;
  if (layers >= 2) {
    final path = Path()
      ..moveTo(inset.left + inset.width * 0.2, inset.top + inset.height * 0.28)
      ..lineTo(inset.left + inset.width * 0.44, inset.top + inset.height * 0.52)
      ..lineTo(inset.left + inset.width * 0.36, inset.top + inset.height * 0.78);
    canvas.drawPath(path, crack);
    canvas.drawPath(
      Path()
        ..moveTo(inset.left + inset.width * 0.7, inset.top + inset.height * 0.2)
        ..lineTo(inset.left + inset.width * 0.62, inset.top + inset.height * 0.48),
      crack,
    );
  } else {
    final path = Path()
      ..moveTo(inset.left + inset.width * 0.24, inset.top + inset.height * 0.2)
      ..lineTo(inset.left + inset.width * 0.46, inset.top + inset.height * 0.46)
      ..lineTo(inset.left + inset.width * 0.32, inset.top + inset.height * 0.62)
      ..lineTo(inset.left + inset.width * 0.52, inset.top + inset.height * 0.84)
      ..moveTo(inset.left + inset.width * 0.72, inset.top + inset.height * 0.22)
      ..lineTo(inset.left + inset.width * 0.62, inset.top + inset.height * 0.42)
      ..moveTo(inset.left + inset.width * 0.66, inset.top + inset.height * 0.7)
      ..lineTo(inset.left + inset.width * 0.78, inset.top + inset.height * 0.86);
    canvas.drawPath(path, crack);
  }
}

/// 界面里的小棋子徽章，用于目标提示与关卡卡片。
class TileBadge extends StatelessWidget {
  const TileBadge({
    super.key,
    required this.type,
    this.size = 26,
    this.special = SpecialType.none,
  });

  final TileType type;
  final double size;
  final SpecialType special;

  @override
  Widget build(BuildContext context) {
    final palette = kTilePalettes[type]!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.light, palette.base],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: palette.deep.withValues(alpha: 0.75),
          width: size * 0.045,
        ),
      ),
      child: Text(
        special == SpecialType.rainbow ? '福' : type.glyph,
        style: TextStyle(
          fontSize: size * 0.48,
          height: 1,
          fontWeight: FontWeight.w700,
          color: special == SpecialType.rainbow ? Colors.white : palette.glyph,
        ),
      ),
    );
  }
}
