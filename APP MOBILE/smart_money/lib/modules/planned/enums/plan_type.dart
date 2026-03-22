/// Loại kế hoạch: Hóa đơn hoặc Giao dịch lặp lại
enum PlanType {
  bill,      // 1 - Hóa đơn (cần duyệt, số tiền có thể thay đổi)
  recurring; // 2 - Giao dịch lặp lại (tự động, số tiền cố định)

  int get value => index + 1;

  static PlanType fromValue(int value) {
    if (value < 1 || value > 2) {
      return PlanType.recurring;
    }
    return PlanType.values[value - 1];
  }

  String get displayName {
    switch (this) {
      case PlanType.bill:
        return 'Hóa đơn';
      case PlanType.recurring:
        return 'Lặp lại';
    }
  }
}

