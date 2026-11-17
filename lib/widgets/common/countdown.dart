import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../theme/app_colors.dart';

/// "Ends in: 12 : 30 : 47" with red boxes whose digits roll every second.
class CountdownBoxes extends StatefulWidget {
  const CountdownBoxes({super.key, required this.endsAt, this.onEnd});

  final DateTime endsAt;
  final VoidCallback? onEnd;

  @override
  State<CountdownBoxes> createState() => _CountdownBoxesState();
}

class _CountdownBoxesState extends State<CountdownBoxes> {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant CountdownBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _tick();
  }

  void _tick() {
    final left = widget.endsAt.difference(DateTime.now());
    if (left.isNegative || left == Duration.zero) {
      widget.onEnd?.call();
    }
    if (mounted) setState(() => _left = left.isNegative ? Duration.zero : left);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int value) => value.toString().padLeft(2, '0');
    final parts = [
      two(_left.inHours.remainder(100)),
      two(_left.inMinutes.remainder(60)),
      two(_left.inSeconds.remainder(60)),
    ];
    return Semantics(
      label:
          'Ends in ${parts[0]} hours ${parts[1]} minutes ${parts[2]} seconds',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ends in: ',
            style: TextStyle(fontSize: 13, color: Appcolors.secondaryText),
          ),
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Appcolors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              width: 26,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Appcolors.sale,
                borderRadius: BorderRadius.circular(4),
              ),
              child: RollingText(
                parts[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
