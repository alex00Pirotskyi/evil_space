import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:evil_space/pixel_alphabet.dart';
import 'package:evil_space/config.dart';

// -----------------------------------------------------------------------
// 1. THE GRID PAINTER
// -----------------------------------------------------------------------
class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------
// 2. THE ULTIMATE "ZERO-MATH" GPU RENDERER
// -----------------------------------------------------------------------
class MatrixPainter extends CustomPainter {
  final Path precalculatedPath;
  final Color color;
  final bool isHovered;

  MatrixPainter({
    required this.precalculatedPath,
    required this.color,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Paint? glowPaint;
    if (isHovered) {
      glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4.0);
    }

    if (glowPaint != null) {
      canvas.drawPath(precalculatedPath, glowPaint);
    }
    canvas.drawPath(precalculatedPath, fillPaint);
    canvas.drawPath(precalculatedPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant MatrixPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isHovered != isHovered;
  }
}

// -----------------------------------------------------------------------
// 3. STATIC HOVERABLE BLOCKS (Logos & Icons)
// -----------------------------------------------------------------------
class HoverablePixelBlock extends StatefulWidget {
  final List<List<int>> matrix;
  final double gridSize;
  final VoidCallback? onTap;

  const HoverablePixelBlock({
    Key? key,
    required this.matrix,
    required this.gridSize,
    this.onTap,
  }) : super(key: key);

  @override
  _HoverablePixelBlockState createState() => _HoverablePixelBlockState();
}

class _HoverablePixelBlockState extends State<HoverablePixelBlock> {
  bool isHovered = false;
  double _opacity = 0.0;
  late Path _cachedPath;

  @override
  void initState() {
    super.initState();
    _buildPath();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  void didUpdateWidget(covariant HoverablePixelBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gridSize != widget.gridSize ||
        oldWidget.matrix != widget.matrix) {
      _buildPath();
    }
  }

  void _buildPath() {
    _cachedPath = Path();
    for (int r = 0; r < widget.matrix.length; r++) {
      for (int c = 0; c < widget.matrix[r].length; c++) {
        if (widget.matrix[r][c] == 1) {
          _cachedPath.addRect(
            Rect.fromLTWH(
              c * widget.gridSize,
              r * widget.gridSize,
              widget.gridSize,
              widget.gridSize,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.matrix[0].length * widget.gridSize;
    double height = widget.matrix.length * widget.gridSize;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: bootFadeMs),
      opacity: _opacity,
      child: RepaintBoundary(
        child: MouseRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            // 🚀 MOBILE TOUCH LOGIC FOR THE LOGO
            onTapDown: (_) => setState(() => isHovered = true),
            onTapCancel: () => setState(() => isHovered = false),
            onTapUp: (_) {
              setState(() => isHovered = false);
              if (widget.onTap != null) widget.onTap!();
            },
            child: TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 150),
              tween: ColorTween(
                begin: const Color(0xFFDDDDDD),
                end: isHovered ? Colors.white : const Color(0xFFDDDDDD),
              ),
              builder: (context, color, child) {
                return CustomPaint(
                  size: Size(width, height),
                  painter: MatrixPainter(
                    precalculatedPath: _cachedPath,
                    color: color ?? const Color(0xFFDDDDDD),
                    isHovered: isHovered,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// 4. STRINGS WITH SIMPLE FADE-IN & MOBILE TOUCH
// -----------------------------------------------------------------------
class HoverablePixelString extends StatefulWidget {
  final String word;
  final double gridSize;
  final VoidCallback? onTap;
  final Duration bootDelay;
  final bool isInstant;

  const HoverablePixelString({
    Key? key,
    required this.word,
    required this.gridSize,
    this.bootDelay = Duration.zero,
    this.isInstant = false,
    this.onTap,
  }) : super(key: key);

  @override
  _HoverablePixelStringState createState() => _HoverablePixelStringState();
}

class _HoverablePixelStringState extends State<HoverablePixelString> {
  bool isHovered = false;
  double _opacity = 0.0;

  late List<Widget> _cachedLetterWidgets;

  // 🚀 Added '/' and ':' to support your new menus and feeds!

  @override
  void initState() {
    super.initState();
    _buildCachedWord();

    if (widget.isInstant) {
      _opacity = 1.0;
    } else {
      Future.delayed(widget.bootDelay, () {
        if (mounted) setState(() => _opacity = 1.0);
      });
    }
  }

  void _buildCachedWord() {
    List<String> lines = widget.word.split('\n');
    List<Widget> lineWidgets = [];

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      String line = lines[lineIndex];
      List<Widget> letterWidgets = [];

      for (int i = 0; i < line.length; i++) {
        String char = line[i].toUpperCase();

        if (char == ' ') {
          letterWidgets.add(SizedBox(width: widget.gridSize * 3));
          continue;
        }

        List<List<int>>? matrix = PixelAlphabet.letters[char];
        if (matrix != null) {
          Path letterPath = Path();
          for (int r = 0; r < matrix.length; r++) {
            for (int c = 0; c < matrix[r].length; c++) {
              if (matrix[r][c] == 1) {
                letterPath.addRect(
                  Rect.fromLTWH(
                    c * widget.gridSize,
                    r * widget.gridSize,
                    widget.gridSize,
                    widget.gridSize,
                  ),
                );
              }
            }
          }

          double width = matrix[0].length * widget.gridSize;
          double height = matrix.length * widget.gridSize;

          letterWidgets.add(
            TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 150),
              tween: ColorTween(
                begin: const Color(0xFFDDDDDD),
                end: isHovered ? Colors.white : const Color(0xFFDDDDDD),
              ),
              builder: (context, color, child) {
                return CustomPaint(
                  size: Size(width, height),
                  painter: MatrixPainter(
                    precalculatedPath: letterPath,
                    color: color ?? const Color(0xFFDDDDDD),
                    isHovered: isHovered,
                  ),
                );
              },
            ),
          );

          if (i < line.length - 1 && line[i + 1] != ' ') {
            letterWidgets.add(SizedBox(width: widget.gridSize));
          }
        }
      }
      lineWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: letterWidgets,
        ),
      );
      if (lineIndex < lines.length - 1)
        lineWidgets.add(SizedBox(height: widget.gridSize * 2));
    }
    _cachedLetterWidgets = lineWidgets;
  }

  @override
  void didUpdateWidget(covariant HoverablePixelString oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildCachedWord();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: bootFadeMs),
      opacity: _opacity,
      child: RepaintBoundary(
        child: MouseRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          // Desktop Hover Logic
          onEnter: (_) {
            if (widget.onTap != null) {
              setState(() {
                isHovered = true;
                _buildCachedWord();
              });
            }
          },
          onExit: (_) {
            if (widget.onTap != null) {
              setState(() {
                isHovered = false;
                _buildCachedWord();
              });
            }
          },
          child: GestureDetector(
            // 🚀 MOBILE TOUCH LOGIC FOR THE TEXT
            onTapDown: (_) {
              if (widget.onTap != null) {
                setState(() {
                  isHovered = true;
                  _buildCachedWord();
                });
              }
            },
            onTapCancel: () {
              if (widget.onTap != null) {
                setState(() {
                  isHovered = false;
                  _buildCachedWord();
                });
              }
            },
            onTapUp: (_) {
              if (widget.onTap != null) {
                setState(() {
                  isHovered = false;
                  _buildCachedWord();
                });
                widget
                    .onTap!(); // Trigger the navigation AFTER the touch is released
              }
            },
            child: Container(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _cachedLetterWidgets,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
