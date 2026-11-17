import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/product_filter.dart';
import '../../core/animations/motion.dart';
import '../../core/utils/money.dart';
import '../../models/products.dart';
import '../../theme/app_colors.dart';

/// Full filter sheet (design page 16). Returns the new [ProductFilter].
/// Animations: collapsible sections (arrow rotates, content resizes), chips
/// and colour swatches animate selection, live result count rolls, staggered
/// sections.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial, required this.scope});

  final ProductFilter initial;

  /// Products in the current category/search before refinements.
  final List<Product> scope;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final ProductController products = Get.find<ProductController>();
  late ProductFilter _filter = widget.initial;
  final _brandSearch = TextEditingController();
  final _sellerSearch = TextEditingController();
  bool _moreBrands = false;
  bool _moreSellers = false;

  late final double _maxPrice = widget.scope.isEmpty
      ? 1000
      : (widget.scope.map((p) => p.price).reduce(math.max) / 50).ceil() * 50.0;

  @override
  void dispose() {
    _brandSearch.dispose();
    _sellerSearch.dispose();
    super.dispose();
  }

  Set<T> _toggle<T>(Set<T> source, T value) {
    HapticFeedback.selectionClick();
    final next = {...source};
    if (!next.remove(value)) next.add(value);
    return next;
  }

  int get _resultCount => _filter.apply(products.visible).length;

  @override
  Widget build(BuildContext context) {
    final subcategories = widget.scope.map((p) => p.subcategory).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final brands = products.brandsIn(widget.scope).toList()..sort();
    final sellers = products.sellersIn(widget.scope).toList()..sort();
    final colors = products.colorsIn(widget.scope);
    final sizes = products.sizesIn(widget.scope).toList();
    const sizeOrder = ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', '5XL', '6XL'];
    sizes.sort((a, b) => sizeOrder.indexOf(a).compareTo(sizeOrder.indexOf(b)));

    final sections = <Widget>[
      if (subcategories.length > 1)
        _Section(
          title: 'Category',
          child: Column(
            children: [
              for (final sub in subcategories)
                InkWell(
                  onTap: () => setState(
                    () => _filter = _filter.copyWith(
                      subcategories: _toggle(_filter.subcategories, sub),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Checkbox(
                            value: _filter.subcategories.contains(sub),
                            onChanged: (_) => setState(
                              () => _filter = _filter.copyWith(
                                subcategories: _toggle(_filter.subcategories, sub),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(sub, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      _Section(
        title: 'Highlight',
        child: _ChipWrap(
          options: const {'promotion': 'Promotions', 'new': 'New Arrivals'},
          selected: _filter.highlights,
          onTap: (value) => setState(
            () => _filter = _filter.copyWith(highlights: _toggle(_filter.highlights, value)),
          ),
        ),
      ),
      if (brands.isNotEmpty)
        _Section(
          title: 'By Brand',
          child: _SearchableChips(
            controller: _brandSearch,
            hint: 'Search brand',
            values: brands,
            selected: _filter.brands,
            expanded: _moreBrands,
            onExpand: () => setState(() => _moreBrands = !_moreBrands),
            onChanged: () => setState(() {}),
            onTap: (value) => setState(
              () => _filter = _filter.copyWith(brands: _toggle(_filter.brands, value)),
            ),
          ),
        ),
      _Section(
        title: 'By Price',
        child: _PriceRange(
          max: _maxPrice,
          value: _filter.priceRange ?? RangeValues(0, _maxPrice),
          onChanged: (range) => setState(() {
            final full = range.start <= 0 && range.end >= _maxPrice;
            _filter = full
                ? _filter.copyWith(clearPrice: true)
                : _filter.copyWith(priceRange: range);
          }),
        ),
      ),
      if (sellers.isNotEmpty)
        _Section(
          title: 'By Manufacturer',
          child: _SearchableChips(
            controller: _sellerSearch,
            hint: 'Search Manufacturer',
            values: sellers,
            selected: _filter.sellers,
            expanded: _moreSellers,
            onExpand: () => setState(() => _moreSellers = !_moreSellers),
            onChanged: () => setState(() {}),
            onTap: (value) => setState(
              () => _filter = _filter.copyWith(sellers: _toggle(_filter.sellers, value)),
            ),
          ),
        ),
      _Section(
        title: 'Delivery & Payment',
        child: _ChipWrap(
          options: const {
            'freeship': 'Free Shipping',
            'cod': 'Payment On Delivery',
            'verified': 'Verified by Ajual',
            'international': 'International Shipping',
          },
          selected: _filter.delivery,
          onTap: (value) => setState(
            () => _filter = _filter.copyWith(delivery: _toggle(_filter.delivery, value)),
          ),
        ),
      ),
      _Section(
        title: 'By Review',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var star = 5; star >= 1; star--)
              _SelectChip(
                selected: _filter.ratings.contains(star),
                onTap: () => setState(
                  () => _filter = _filter.copyWith(ratings: _toggle(_filter.ratings, star)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Appcolors.star),
                    const SizedBox(width: 3),
                    Text('$star'),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (colors.isNotEmpty)
        _Section(
          title: 'By Color',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in colors.entries)
                _ColorDot(
                  name: entry.key,
                  color: _parseHex(entry.value),
                  selected: _filter.colors.contains(entry.key),
                  onTap: () => setState(
                    () => _filter = _filter.copyWith(colors: _toggle(_filter.colors, entry.key)),
                  ),
                ),
            ],
          ),
        ),
      if (sizes.isNotEmpty)
        _Section(
          title: 'By Size',
          child: _ChipWrap(
            options: {for (final s in sizes) s: s},
            selected: _filter.sizes,
            onTap: (value) => setState(
              () => _filter = _filter.copyWith(sizes: _toggle(_filter.sizes, value)),
            ),
          ),
        ),
    ];

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Filter', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Container(
                      key: ValueKey(_filter.activeCount),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: Appcolors.field,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_filter.activeCount}', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: staggered(sections, stepMs: 40),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Appcolors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () => setState(() => _filter = _filter.cleared()),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(46),
                          border: Border.all(color: Appcolors.border),
                        ),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: Appcolors.sale, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressableScale(
                      onTap: () => Navigator.pop(context, _filter),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Appcolors.primary,
                          borderRadius: BorderRadius.circular(46),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'View Results ',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            RollingText(
                              '($_resultCount)',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseHex(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0;
    return Color(0xFF000000 | value);
  }
}

class _Section extends StatefulWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0 : 0.5,
                  duration: const Duration(milliseconds: 240),
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(padding: const EdgeInsets.only(bottom: 10), child: widget.child)
              : const SizedBox(width: double.infinity),
        ),
        const Divider(),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Appcolors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Appcolors.primary : Appcolors.border),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Appcolors.text,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: selected ? Colors.white : Appcolors.text),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.options, required this.selected, required this.onTap});

  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          _SelectChip(
            selected: selected.contains(entry.key),
            onTap: () => onTap(entry.key),
            child: Text(entry.value),
          ),
      ],
    );
  }
}

class _SearchableChips extends StatelessWidget {
  const _SearchableChips({
    required this.controller,
    required this.hint,
    required this.values,
    required this.selected,
    required this.expanded,
    required this.onExpand,
    required this.onChanged,
    required this.onTap,
  });

  final TextEditingController controller;
  final String hint;
  final List<String> values;
  final Set<String> selected;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onChanged;
  final ValueChanged<String> onTap;

  static const int _collapsed = 6;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final matches = values.where((v) => v.toLowerCase().contains(query)).toList();
    final visible = expanded || query.isNotEmpty ? matches : matches.take(_collapsed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: const Icon(Icons.search, size: 18, color: Appcolors.secondaryText),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          alignment: Alignment.topCenter,
          child: _ChipWrap(
            options: {for (final v in visible) v: v},
            selected: selected,
            onTap: onTap,
          ),
        ),
        if (query.isEmpty && matches.length > _collapsed)
          TextButton.icon(
            onPressed: onExpand,
            style: TextButton.styleFrom(
              foregroundColor: Appcolors.secondaryText,
              padding: EdgeInsets.zero,
            ),
            icon: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ),
            label: Text(expanded ? 'Show Less' : 'Show More', style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _PriceRange extends StatelessWidget {
  const _PriceRange({required this.max, required this.value, required this.onChanged});

  final double max;
  final RangeValues value;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(Money.format(value.start), style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText)),
            const Spacer(),
            Text(Money.format(value.end), style: const TextStyle(fontSize: 12, color: Appcolors.secondaryText)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Appcolors.primary,
            inactiveTrackColor: Appcolors.border,
            thumbColor: Appcolors.primary,
            overlayColor: Appcolors.primary.withValues(alpha: 0.08),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values: RangeValues(
              value.start.clamp(0, max).toDouble(),
              value.end.clamp(0, max).toDouble(),
            ),
            min: 0,
            max: max,
            divisions: math.max(1, math.min(500, (max / 10).round())),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: name,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            // Overshooting while shrinking would make the padding negative.
            curve: selected ? Curves.easeOutBack : Curves.easeOutCubic,
            width: 32,
            height: 32,
            padding: EdgeInsets.all(selected ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Appcolors.primary : Appcolors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
