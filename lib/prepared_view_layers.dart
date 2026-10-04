import 'package:flutter/material.dart';

/// Persistent views. Animation frames update render opacity, not widget trees.
class PreparedViewLayers extends StatefulWidget {
  const PreparedViewLayers({super.key, required this.controller,
    required this.first, this.second, this.blockFirst = false});

  final AnimationController controller;
  final Widget first;
  final Widget? second;
  final bool blockFirst;

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
      curve: Curves.easeInOutCubic);
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
                child: RepaintBoundary(child: child)))))));

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
