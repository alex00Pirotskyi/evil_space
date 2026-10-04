import 'package:flutter/material.dart';

const preparedViewDuration = Duration(milliseconds: 450);
const preparedViewCurve = Curves.easeInOutCubic;
const preparedViewTravel = 8.0;

/// A small paint-only rise as content becomes visible, and fall as it fades.
/// Layout and the retained child stay unchanged on animation frames.
class PreparedViewMotion extends StatelessWidget {
  const PreparedViewMotion({super.key, required this.visibility,
    required this.child, this.travelPixels = preparedViewTravel});

  final Animation<double> visibility;
  final Widget child;
  final double travelPixels;

  @override
  Widget build(BuildContext context) {
    if (travelPixels == 0 || MediaQuery.disableAnimationsOf(context)) return child;
    return LayoutBuilder(builder: (_, constraints) {
      final height = constraints.maxHeight;
      if (!height.isFinite || height <= 0) return child;
      return SlideTransition(
        position: visibility.drive(Tween<Offset>(
          begin: Offset(0, travelPixels / height), end: Offset.zero)),
        transformHitTests: false, child: child);
    });
  }
}

/// Persistent views. Frames update opacity and paint position, not page builds.
class PreparedViewLayers extends StatefulWidget {
  const PreparedViewLayers({super.key, required this.controller,
    required this.first, this.second, this.blockFirst = false,
    this.travelPixels = preparedViewTravel});

  final AnimationController controller;
  final Widget first;
  final Widget? second;
  final bool blockFirst;
  final double travelPixels;

  @override
  State<PreparedViewLayers> createState() => _PreparedViewLayersState();
}

class _PreparedViewLayersState extends State<PreparedViewLayers> {
  late CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _fade = CurvedAnimation(parent: widget.controller,
      curve: preparedViewCurve);
    widget.controller.addStatusListener(_statusChanged);
  }

  void _statusChanged(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PreparedViewLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeStatusListener(_statusChanged);
      _fade.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    widget.controller.removeStatusListener(_statusChanged);
    _fade.dispose();
    super.dispose();
  }

  Widget _layer(Widget child, {required bool hidden, required bool interactive,
    required Animation<double> opacity}) => Offstage(
      offstage: hidden,
      child: TickerMode(enabled: !hidden,
        child: IgnorePointer(ignoring: !interactive,
          child: ExcludeFocus(excluding: !interactive,
            child: ExcludeSemantics(excluding: !interactive,
              child: FadeTransition(opacity: opacity,
                child: PreparedViewMotion(visibility: opacity,
                  travelPixels: widget.travelPixels,
                  child: RepaintBoundary(child: child))))))));

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    _layer(widget.first, hidden: widget.controller.isCompleted,
      interactive: widget.controller.isDismissed && !widget.blockFirst,
      opacity: ReverseAnimation(_fade)),
    if (widget.second != null)
      _layer(widget.second!, hidden: widget.controller.isDismissed,
        interactive: widget.controller.isCompleted, opacity: _fade),
  ]);
}
