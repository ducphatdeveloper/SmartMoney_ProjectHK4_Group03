/// Trạng thái mục tiêu tiết kiệm — đồng bộ GoalStatus.java (server):
///   ACTIVE(1)    : Đang hoạt động
///   COMPLETED(2) : Hoàn thành (đủ tiền) — KHÔNG kích hoạt lại
///   CANCELLED(3) : Tạm dừng (deleted=false) — CÓ THỂ kích hoạt lại
///   OVERDUE(4)   : Quá hạn chưa đủ tiền    — CÓ THỂ kích hoạt lại
enum GoalStatus {
  active,     // 1 - Đang hoạt động
  completed,  // 2 - Hoàn thành (đủ tiền) — KHÔNG kích hoạt lại
  cancelled,  // 3 - Tạm dừng / kết thúc sớm — CÓ THỂ kích hoạt lại
  overdue;    // 4 - Quá hạn chưa đủ tiền — CÓ THỂ kích hoạt lại

  int get value => index + 1;

  static GoalStatus fromValue(int value) {
    if (value < 1 || value > 4) {
      return GoalStatus.active;
    }
    return GoalStatus.values[value - 1];
  }

  String get displayName {
    switch (this) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.cancelled:
        return 'Paused';
      case GoalStatus.overdue:
        return 'Overdue';
    }
  }

  /// Tab Active  : ACTIVE(1) + OVERDUE(4)
  bool get isRunning =>
      this == GoalStatus.active || this == GoalStatus.overdue;

  /// Tab Finished: COMPLETED(2) + CANCELLED(3=tạm dừng)
  bool get isDone =>
      this == GoalStatus.completed || this == GoalStatus.cancelled;

  /// Có thể toggle kích hoạt lại (CANCELLED + OVERDUE)
  bool get isReactivatable =>
      this == GoalStatus.cancelled || this == GoalStatus.overdue;
}