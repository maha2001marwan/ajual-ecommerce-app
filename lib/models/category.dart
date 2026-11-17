class Subcategory {
  const Subcategory({required this.name, required this.image});

  final String name;
  final String image;

  Map<String, dynamic> toMap() => {'name': name, 'image': image};

  factory Subcategory.fromMap(Map<String, dynamic> map) => Subcategory(
    name: map['name'] as String? ?? '',
    image: map['image'] as String? ?? '',
  );
}

/// A top-level shop department shown on the Categories tab.
class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.order,
    this.subcategories = const [],
  });

  final String id;
  final String name;
  final int order;
  final List<Subcategory> subcategories;

  /// "Consumer Electric" → "Consumer\nElectric" for the narrow side rail.
  String get railLabel {
    final index = name.indexOf(' & ');
    if (index > 0) return '${name.substring(0, index)}\n${name.substring(index + 1)}';
    final space = name.indexOf(' ');
    return space > 0 ? '${name.substring(0, space)}\n${name.substring(space + 1)}' : name;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'order': order,
    'subcategories': subcategories.map((s) => s.toMap()).toList(),
  };

  factory ShopCategory.fromMap(Map<String, dynamic> map) => ShopCategory(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    order: (map['order'] as num?)?.toInt() ?? 0,
    subcategories: (map['subcategories'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Subcategory.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
