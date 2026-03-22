/// Loại nợ: Phải trả (Đi vay) hoặc Phải thu (Cho vay)
enum DebtType {
  payable,   // 0 - Phải trả (Đi vay)
  receivable; // 1 - Phải thu (Cho vay)

  int get value => index;

  static DebtType fromValue(int value) {
    return DebtType.values[value];
  }

  static DebtType? fromValueOrNull(int? value) {
    if (value == null || value < 0 || value >= DebtType.values.length) {
      return null;
    }
    return DebtType.values[value];
  }

  String get displayName {
    switch (this) {
      case DebtType.payable:
        return 'Cần trả (Đi vay)';
      case DebtType.receivable:
        return 'Cần thu (Cho vay)';
    }
  }
}

