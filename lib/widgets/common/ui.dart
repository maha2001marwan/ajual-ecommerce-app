import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/utils/money.dart';
import '../../theme/app_colors.dart';

/// "Flash Sale ............ View All" row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action = 'View All',
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String title;
  final String action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            // Shrinks (e.g. the countdown) rather than colliding with the
            // title on narrow screens.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
          if (onAction != null && trailing == null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Appcolors.text,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 12,
    this.count,
  });

  final double rating;
  final double size;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : (rating >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_rounded),
            size: size,
            color: rating >= i - 0.5 ? Appcolors.star : const Color(0xFFDADADA),
          ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            count!.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: size * 0.9,
              color: Appcolors.secondaryText,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tappable stars for the review form; each star pops when picked.
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            label: '$i star${i == 1 ? '' : 's'}',
            child: GestureDetector(
              onTap: () => onChanged(i.toDouble()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedScale(
                  scale: value >= i ? 1.15 : 1,
                  duration: Duration(milliseconds: 160 + i * 40),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.star_rounded,
                    size: size,
                    color: value >= i
                        ? Appcolors.star
                        : const Color(0xFFDADADA),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Current price (red when discounted) followed by the struck-through one.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.price,
    this.oldPrice = 0,
    this.size = 14,
    this.color,
    this.showPercent = false,
  });

  final double price;
  final double oldPrice;
  final double size;
  final Color? color;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final discounted = oldPrice > price;
    final percent = discounted ? ((1 - price / oldPrice) * 100).round() : 0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          Money.format(price),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color ?? (discounted ? Appcolors.sale : Appcolors.text),
          ),
        ),
        if (discounted)
          Text(
            Money.format(oldPrice),
            style: TextStyle(
              fontSize: size * 0.78,
              color: Appcolors.hint,
              decoration: TextDecoration.lineThrough,
              decorationColor: Appcolors.hint,
            ),
          ),
        if (discounted && showPercent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$percent% OFF',
              style: const TextStyle(
                color: Appcolors.sale,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Page dots where the active one stretches into a pill (or, with
/// [stretch] off, stays round and pops slightly as in the home design).
class DotsIndicator extends StatelessWidget {
  const DotsIndicator({
    super.key,
    required this.count,
    required this.index,
    this.activeColor = Appcolors.primary,
    this.color = const Color(0xFFDADADA),
    this.size = 6,
    this.stretch = true,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color color;
  final double size;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedScale(
            scale: !stretch && i == index ? 1.15 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(
                horizontal: stretch ? 3 : size * 0.55,
              ),
              width: stretch && i == index ? size * 3 : size,
              height: size,
              decoration: BoxDecoration(
                color: i == index ? activeColor : color,
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
      ],
    );
  }
}

/// Black (or outlined) pill button whose label morphs into a spinner.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.height = 52,
    this.icon,
    this.loadingLabel,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final double height;
  final IconData? icon;
  final String? loadingLabel;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? Appcolors.text : Colors.white;
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: loading
          ? Row(
              key: const ValueKey('loading'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                if (loadingLabel != null) ...[
                  const SizedBox(width: 10),
                  Text(loadingLabel!, style: TextStyle(color: fg)),
                ],
              ],
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: height < 46 ? 14 : 16,
                    ),
                  ),
                ),
              ],
            ),
    );

    final button = PressableScale(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: outlined
              ? Colors.white
              : (onPressed == null && !loading
                    ? const Color(0xFFBDBDBD)
                    : Appcolors.primary),
          borderRadius: BorderRadius.circular(height),
          border: outlined ? Border.all(color: Appcolors.border) : null,
        ),
        // widthFactor keeps compact buttons hugging their label.
        child: Center(widthFactor: 1, child: child),
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// White block separated by a light grey band, as in the design sections.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.title,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Label + value row used in order summaries.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.oldValue,
    this.valueColor,
    this.bold = false,
    this.animate = true,
  });

  final String label;
  final double value;
  final double? oldValue;
  final Color? valueColor;
  final bool bold;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 18 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: valueColor ?? Appcolors.text,
    );
    String format(double v) =>
        valueColor == Appcolors.sale ? '- ${Money.format(v)}' : Money.format(v);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 18 : 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: Appcolors.text,
              ),
            ),
          ),
          if (oldValue != null && oldValue! > value) ...[
            Text(
              Money.format(oldValue!),
              style: const TextStyle(
                fontSize: 11,
                color: Appcolors.hint,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
          ],
          animate
              ? AnimatedNumber(value: value, format: format, style: style)
              : Text(format(value), style: style),
        ],
      ),
    );
  }
}

/// Dashed horizontal line (summary separators, coupon tickets).
class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.color = const Color(0xFFDADADA),
    this.dash = 5,
    this.gap = 4,
  });

  final Color color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: dash,
                height: 1,
                margin: EdgeInsets.only(right: gap),
                color: color,
              ),
          ],
        );
      },
    );
  }
}

/// Grey labelled form field with the design's look.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Appcolors.sale),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Dropdown styled like the grey design fields (with the ⇕ chevrons).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.hint = 'Select',
    this.validator,
  });

  final List<T> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String Function(T value) labelOf;
  final String hint;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    final current = items.contains(value) ? value : null;
    return DropdownButtonFormField<T>(
      // FormField keeps its own value, so rebuild when the source changes.
      key: ValueKey(
        '${current}_${items.length}_${items.isEmpty ? '' : items.first}',
      ),
      initialValue: current,
      isExpanded: true,
      validator: validator,
      onChanged: onChanged,
      icon: const Icon(
        Icons.unfold_more_rounded,
        color: Appcolors.secondaryText,
      ),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
      hint: Text(
        hint,
        style: const TextStyle(color: Appcolors.hint, fontSize: 14),
      ),
      style: const TextStyle(color: Appcolors.text, fontSize: 14),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
      ],
    );
  }
}

/// "🔒 All data will be encrypted" footer note.
class EncryptedNote extends StatelessWidget {
  const EncryptedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: Appcolors.secondaryText,
          ),
          SizedBox(width: 6),
          Text(
            'All data will be encrypted',
            style: TextStyle(fontSize: 12, color: Appcolors.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// Small amber pill marking demo-only features (free Firebase plan).
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'DEMO'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9A6B00),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
