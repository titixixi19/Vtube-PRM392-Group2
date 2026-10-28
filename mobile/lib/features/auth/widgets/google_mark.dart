import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chữ "G" nhiều màu của Google, vẽ bằng CustomPaint (không cần thêm package SVG).
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  // Màu thương hiệu Google, chỉ dùng cho logo này nên không đưa vào AppColors.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double deg) => deg * math.pi / 180;

    // Góc 0 = hướng 3 giờ, chiều kim đồng hồ. Chừa khoảng hở phía trên bên phải.
    canvas.drawArc(rect, rad(215), rad(105), false, arc(_red));
    canvas.drawArc(rect, rad(135), rad(80), false, arc(_yellow));
    canvas.drawArc(rect, rad(45), rad(90), false, arc(_green));
    canvas.drawArc(rect, rad(0), rad(45), false, arc(_blue));
    // Gạch ngang của chữ G
    canvas.drawRect(Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2, stroke), Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
