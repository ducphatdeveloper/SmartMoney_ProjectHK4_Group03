/// Loại danh mục: Chi tiêu hoặc Thu nhập
enum CategoryType {
  expense, // 0 - Chi tiêu
  income;  // 1 - Thu nhập

  int get value => index;

  static CategoryType fromValue(int value) {
    return CategoryType.values[value];
  }

  static CategoryType? fromValueOrNull(int? value) {
    if (value == null || value < 0 || value >= CategoryType.values.length) {
      return null;
    }
    return CategoryType.values[value];
  }

  String get displayName {
    switch (this) {
      case CategoryType.expense:
        return 'Chi tiêu';
      case CategoryType.income:
        return 'Thu nhập';
    }
  }
}

