class TransactionCategory {

  TransactionCategory({
    required this.id,
    required this.name,
    required this.type, this.icon,
    this.parentId,
    this.subcategories = const [],
  });

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      type: json['type'] as String? ?? 'expense',
      parentId: json['parent_id'] as String?,
      subcategories:
          (json['subcategories'] as List?)
              ?.map((i) => TransactionCategory.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  final String id;
  final String name;
  final String? icon;
  final String type;
  final String? parentId;
  final List<TransactionCategory> subcategories;

  String get displayIcon {
    if (icon != null && icon!.isNotEmpty) return icon!;

    final lowerName = name.toLowerCase();
    const defaultIcons = {
      'food': '🍔',
      'groceries': '🛒',
      'rent': '🏠',
      'shopping': '🛍️',
      'transport': '🚗',
      'travel': '✈️',
      'health': '💊',
      'entertainment': '🎬',
      'utilities': '💡',
      'salary': '💰',
      'transfer': '↔️',
      'investment': '📈',
      'education': '🎓',
      'gift': '🎁',
      'other': '📦',
      'uncategorized': '📁'
    };

    for (var entry in defaultIcons.entries) {
      if (lowerName.contains(entry.key)) return entry.value;
    }

    return '🏷️';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'type': type,
      'parent_id': parentId,
      'subcategories': subcategories.map((s) => s.toJson()).toList(),
    };
  }
}
