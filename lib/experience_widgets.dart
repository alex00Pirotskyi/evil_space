import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/pixel_emoji.dart';
import 'package:evil_space/pixeltools.dart';

enum DevilState {
  idle,
  hoverLeft,
  hoverRight,
  happy,
  sleep,
  success,
}

class PixelDevilMascot extends StatelessWidget {
  const PixelDevilMascot({
    super.key,
    required this.gridSize,
    required this.state,
    required this.onTap,
  });

  final double gridSize;
  final DevilState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final offset = switch (state) {
      DevilState.hoverLeft => const Offset(-0.06, 0),
      DevilState.hoverRight => const Offset(0.06, 0),
      DevilState.happy => const Offset(0, -0.05),
      DevilState.success => const Offset(0, -0.08),
      DevilState.sleep || DevilState.idle => Offset.zero,
    };
    final scale = switch (state) {
      DevilState.success => 1.08,
      DevilState.happy => 1.04,
      DevilState.sleep => 0.96,
      _ => 1.0,
    };
    final color = switch (state) {
      DevilState.sleep => const Color(0xFF888888),
      DevilState.success || DevilState.happy => Colors.white,
      _ => const Color(0xFFEEEEEE),
    };

    return AnimatedSlide(
      offset: offset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: state == DevilState.sleep ? 0.72 : 1,
          duration: const Duration(milliseconds: 220),
          child: HoverablePixelBlock(
            matrix: Pixelemoji.devilUnframed,
            gridSize: gridSize,
            semanticLabel: 'Evil Space home',
            color: color,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class PixelFloorMap extends StatelessWidget {
  const PixelFloorMap({
    super.key,
    required this.status,
    required this.gridSize,
    required this.selectedDeskId,
    required this.onSelectDesk,
    required this.onWorkHere,
    required this.translate,
  });

  final CoworkingStatus status;
  final double gridSize;
  final String? selectedDeskId;
  final ValueChanged<String> onSelectDesk;
  final ValueChanged<String> onWorkHere;
  final String Function(String key) translate;

  @override
  Widget build(BuildContext context) {
    final selected = status.deskById(selectedDeskId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _zoneLabel(translate('map_window')),
        SizedBox(height: gridSize * 2),
        LayoutBuilder(
          builder: (context, constraints) {
            final preferredWidth = math.max(96.0, gridSize * 19).toDouble();
            final columns = math
                .max(2, (constraints.maxWidth / preferredWidth).floor())
                .toInt();
            final tileWidth =
                (constraints.maxWidth - ((columns - 1) * gridSize * 2)) /
                    columns;

            return Wrap(
              spacing: gridSize * 2,
              runSpacing: gridSize * 2,
              children: status.desks.map((desk) {
                return SizedBox(
                  width: tileWidth,
                  child: _DeskTile(
                    desk: desk,
                    selected: desk.id == selectedDeskId,
                    gridSize: gridSize,
                    onTap: () => onSelectDesk(desk.id),
                    translate: translate,
                  ),
                );
              }).toList(),
            );
          },
        ),
        SizedBox(height: gridSize * 3),
        Row(
          children: [
            Expanded(child: _zoneBox(translate('map_coffee'))),
            SizedBox(width: gridSize * 2),
            Expanded(child: _zoneBox(translate('map_office'))),
          ],
        ),
        SizedBox(height: gridSize * 2),
        Row(
          children: [
            Expanded(child: _zoneBox(translate('map_studio'))),
            SizedBox(width: gridSize * 2),
            Expanded(child: _zoneBox(translate('map_entrance'))),
          ],
        ),
        if (selected != null) ...[
          SizedBox(height: gridSize * 5),
          HoverablePixelString(
            word: '${selected.label} / ${selected.zone}',
            gridSize: gridSize,
            isInstant: true,
            color: Colors.white,
          ),
          SizedBox(height: gridSize * 2),
          HoverablePixelString(
            word: translate(_stateKey(selected.state)),
            gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
            isInstant: true,
            color: _stateColor(selected.state),
          ),
          if (selected.state == DeskState.available) ...[
            SizedBox(height: gridSize * 3),
            HoverablePixelString(
              word: translate('cta_work_here'),
              gridSize: gridSize,
              isInstant: true,
              color: Colors.white,
              hoverColor: Colors.white,
              onTap: () => onWorkHere(selected.id),
            ),
          ],
        ],
      ],
    );
  }

  Widget _zoneLabel(String text) {
    return HoverablePixelString(
      word: text,
      gridSize: math.max(3.0, gridSize * 0.75).toDouble(),
      isInstant: true,
      color: const Color(0xFFAAAAAA),
    );
  }

  Widget _zoneBox(String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.all(gridSize * 2),
      decoration: BoxDecoration(
        color: const Color(0x77000000),
        border: Border.all(color: const Color(0xFF666666)),
      ),
      alignment: Alignment.centerLeft,
      child: HoverablePixelString(
        word: text,
        gridSize: math.max(3.0, gridSize * 0.7).toDouble(),
        isInstant: true,
        color: const Color(0xFFBDBDBD),
      ),
    );
  }

  static String _stateKey(DeskState state) {
    return switch (state) {
      DeskState.available => 'desk_state_available',
      DeskState.occupied => 'desk_state_occupied',
      DeskState.reserved => 'desk_state_reserved',
      DeskState.offline => 'desk_state_offline',
    };
  }

  static Color _stateColor(DeskState state) {
    return switch (state) {
      DeskState.available => Colors.white,
      DeskState.reserved => const Color(0xFFB0B0B0),
      DeskState.occupied => const Color(0xFF777777),
      DeskState.offline => const Color(0xFF555555),
    };
  }
}

class _DeskTile extends StatelessWidget {
  const _DeskTile({
    required this.desk,
    required this.selected,
    required this.gridSize,
    required this.onTap,
    required this.translate,
  });

  final DeskInfo desk;
  final bool selected;
  final double gridSize;
  final VoidCallback onTap;
  final String Function(String key) translate;

  @override
  Widget build(BuildContext context) {
    final stateKey = switch (desk.state) {
      DeskState.available => 'desk_state_available_short',
      DeskState.occupied => 'desk_state_occupied_short',
      DeskState.reserved => 'desk_state_reserved_short',
      DeskState.offline => 'desk_state_offline_short',
    };
    final baseColor = switch (desk.state) {
      DeskState.available => Colors.white,
      DeskState.reserved => const Color(0xFFAAAAAA),
      DeskState.occupied => const Color(0xFF707070),
      DeskState.offline => const Color(0xFF4D4D4D),
    };

    return Semantics(
      button: true,
      label: '${desk.label}, ${translate(stateKey)}',
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: 82),
          padding: EdgeInsets.all(gridSize * 2),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x66000000)
                : const Color(0x44000000),
            border: Border.all(
              color: selected ? Colors.white : baseColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HoverablePixelString(
                word: desk.label,
                gridSize: gridSize,
                isInstant: true,
                color: baseColor,
              ),
              SizedBox(height: gridSize),
              HoverablePixelString(
                word: translate(stateKey),
                gridSize: math.max(3.0, gridSize * 0.6).toDouble(),
                isInstant: true,
                color: baseColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
