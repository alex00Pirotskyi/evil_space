import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart';

/// Isolated design study. Does not load production routes or services.
class PremiumPaperWidget extends StatefulWidget {
  const PremiumPaperWidget({super.key});

  @override
  State<PremiumPaperWidget> createState() => _PremiumPaperWidgetState();
}

class _PremiumPaperWidgetState extends State<PremiumPaperWidget> {
  FragmentShader? _shader;
  Offset? _lightPosition;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await FragmentProgram.fromAsset('shaders/paper_shader.frag');
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (error) {
      // Solid dark fallback for devices without shader support.
      debugPrint('Evil Space preview shader unavailable: $error');
    }
  }

  void _moveLight(Offset position) {
    if (_lightPosition == position) return;
    setState(() => _lightPosition = position);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF050505),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerHover: (event) => _moveLight(event.localPosition),
        onPointerDown: (event) => _moveLight(event.localPosition),
        onPointerMove: (event) => _moveLight(event.localPosition),
        child: _shader == null
            ? const SizedBox.expand()
            : CustomPaint(
                painter: _PaperShaderPainter(_shader!, _lightPosition),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _PaperShaderPainter extends CustomPainter {
  const _PaperShaderPainter(this.shader, this.lightPosition);

  final FragmentShader shader;
  final Offset? lightPosition;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pointer = lightPosition ?? Offset(size.width / 2, size.height / 2);
    // Uniform order matches shaders/paper_shader.frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, pointer.dx)
      ..setFloat(3, pointer.dy)
      ..setFloat(4, 0.0);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _PaperShaderPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.lightPosition != lightPosition;
}
