import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/product_filter.dart';
import '../../core/animations/motion.dart';
import '../../models/category.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_image.dart';
import '../products/product_list_screen.dart';

/// Search (design pages 12 & 13): recent searches and trending categories,
/// live suggestions while typing.
/// Animations: search field flies in from Home (Hero), cross-fade between
/// idle and typing states, staggered rows, recent items collapse when
/// removed, matched text highlighted.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ProductController products = Get.find<ProductController>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Focus after the Hero flight so the keyboard doesn't fight it.
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    products.addRecentSearch(query);
    FocusScope.of(context).unfocus();
    Get.off(
      () => ProductListScreen(
        title: query,
        initialFilter: ProductFilter(query: query),
      ),
      transition: Transition.cupertino,
    );
  }

  void _openCategory(ShopCategory category, Subcategory sub) {
    Get.off(
      () => ProductListScreen(
        title: sub.name,
        initialFilter: ProductFilter(
          category: category.name,
          subcategories: {sub.name},
        ),
      ),
      transition: Transition.cupertino,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        titleWidget: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: HeaderSearchField(
            heroTag: 'header-search',
            controller: _controller,
            focusNode: _focus,
            showCamera: true,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: _submit,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        child: _query.trim().isEmpty ? _idle() : _suggestions(),
      ),
    );
  }

  Widget _idle() {
    return Obx(() {
      final recent = products.recentSearches.toList();
      final trending = <(ShopCategory, Subcategory)>[
        for (final category in products.categories)
          for (final sub in category.subcategories.take(2)) (category, sub),
      ].take(9).toList();
      return ListView(
        key: const ValueKey('idle'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          if (recent.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recently Search',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: products.clearRecentSearches,
                  style: TextButton.styleFrom(foregroundColor: Appcolors.text),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: staggered(
                  [
                    for (final item in recent)
                      _RecentRow(
                        key: ValueKey(item),
                        text: item,
                        onTap: () => _submit(item),
                        onRemove: () => products.removeRecentSearch(item),
                      ),
                  ],
                  stepMs: 40,
                  offset: const Offset(0.08, 0),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
          ],
          const Text(
            'Trending Categories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          // Fixed-width tiles whose height follows their content: a grid
          // cell with a fixed aspect ratio overflowed for two-line names.
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final tileWidth = (constraints.maxWidth - spacing * 2) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: 16,
                children: staggered(
                  [
                    for (final entry in trending)
                      SizedBox(
                        width: tileWidth,
                        child: PressableScale(
                          onTap: () => _openCategory(entry.$1, entry.$2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: AppImage(entry.$2.image),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.$2.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  startIndex: recent.length,
                  stepMs: 50,
                ),
              );
            },
          ),
        ],
      );
    });
  }

  Widget _suggestions() {
    final items = products.suggestionsFor(_query);
    return ListView(
      key: const ValueKey('suggestions'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _SuggestionRow(
          text: _query.trim(),
          query: _query,
          onTap: () => _submit(_query),
        ),
        for (var i = 0; i < items.length; i++)
          FadeSlideIn(
            delay: Motion.stagger(i, stepMs: 30),
            offset: const Offset(0, 0.25),
            child: _SuggestionRow(
              text: items[i],
              query: _query,
              onTap: () => _submit(items[i]),
            ),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    super.key,
    required this.text,
    required this.onTap,
    required this.onRemove,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 18,
              color: Appcolors.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Appcolors.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Suggestion with the typed part in regular weight and the rest bold.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.text,
    required this.query,
    required this.onTap,
  });

  final String text;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final q = query.trim().toLowerCase();
    final index = q.isEmpty ? -1 : lower.indexOf(q);
    final spans = <TextSpan>[];
    if (index < 0) {
      spans.add(
        TextSpan(
          text: text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else {
      if (index > 0) {
        spans.add(
          TextSpan(
            text: text.substring(0, index),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }
      spans.add(TextSpan(text: text.substring(index, index + q.length)));
      spans.add(
        TextSpan(
          text: text.substring(index + q.length),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: Appcolors.secondaryText),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: spans),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Appcolors.text),
              ),
            ),
            const Icon(
              Icons.north_west_rounded,
              size: 16,
              color: Appcolors.hint,
            ),
          ],
        ),
      ),
    );
  }
}
