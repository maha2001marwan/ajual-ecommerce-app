import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_ui.dart';

/// Row of single-digit boxes backed by one invisible text field, so typing,
/// backspace, paste and SMS/email code autofill all behave like a normal input.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 4,
    this.hasError = false,
    this.enabled = true,
    this.onCompleted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput>
    with SingleTickerProviderStateMixin {
  static const double _boxSize = 64;
  static const double _gap = 16;

  late final AnimationController _cursor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 530),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
    widget.focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    widget.focusNode.removeListener(_refresh);
    _cursor.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _handleChanged() {
    final controller = widget.controller;
    // Keep the caret at the end: digits are always appended or removed there.
    final end = TextSelection.collapsed(offset: controller.text.length);
    if (controller.selection != end) controller.selection = end;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final focused = widget.focusNode.hasFocus;
    final activeIndex = math.min(text.length, widget.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _gap * (widget.length - 1);
        final boxSize = math.min(_boxSize, available / widget.length);
        return Stack(
          alignment: Alignment.center,
          children: [
            // The real input sits underneath and receives the taps.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                    if (value.length == widget.length) {
                      widget.onCompleted?.call(value);
                    }
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    _OtpBox(
                      size: boxSize,
                      digit: i < text.length ? text[i] : null,
                      isActive: focused && i == activeIndex,
                      hasError: widget.hasError,
                      cursor: _cursor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.size,
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.cursor,
  });

  final double size;
  final String? digit;
  final bool isActive;
  final bool hasError;
  final Animation<double> cursor;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError
        ? AuthColors.error
        : isActive
        ? AuthColors.black
        : Colors.transparent;

    final Widget content;
    if (digit != null) {
      content = Text(
        digit!,
        style: AuthText.input.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (isActive) {
      content = FadeTransition(
        opacity: cursor,
        child: Container(width: 1.5, height: 22, color: AuthColors.black),
      );
    } else {
      content = Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AuthColors.placeholderDot,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AuthColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: content,
    );
  }
}
