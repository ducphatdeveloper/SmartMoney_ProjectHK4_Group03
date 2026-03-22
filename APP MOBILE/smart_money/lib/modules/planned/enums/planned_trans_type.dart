/// Loại giao dịch từ kế hoạch: Chi, Thu, Cho vay, Đi vay, Thu nợ, Trả nợ
enum PlannedTransType {
  expense,      // 1 - Chi
  income,       // 2 - Thu
  loanOut,      // 3 - Cho vay
  loanIn,       // 4 - Đi vay
  debtCollect,  // 5 - Thu nợ
  debtRepay;    // 6 - Trả nợ

  int get value => index + 1;

  static PlannedTransType fromValue(int value) {
    if (value < 1 || value > 6) {
      return PlannedTransType.expense;
    }
    return PlannedTransType.values[value - 1];
  }

  String get displayName {
    switch (this) {
      case PlannedTransType.expense:
        return 'Chi';
      case PlannedTransType.income:
        return 'Thu';
      case PlannedTransType.loanOut:
        return 'Cho vay';
      case PlannedTransType.loanIn:
        return 'Đi vay';
      case PlannedTransType.debtCollect:
        return 'Thu nợ';
      case PlannedTransType.debtRepay:
        return 'Trả nợ';
    }
  }
}

