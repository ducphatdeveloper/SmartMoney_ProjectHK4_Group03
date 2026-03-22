/// Trạng thái mục tiêu tiết kiệm: Đang hoạt động, Hoàn thành, Hủy, Quá hạn
enum GoalStatus {
  active,     // 1 - Đang hoạt động
  completed,  // 2 - Hoàn thành
  cancelled,  // 3 - Hủy
  overdue;    // 4 - Quá hạn

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
        return 'Đang hoạt động';
      case GoalStatus.completed:
        return 'Hoàn thành';
      case GoalStatus.cancelled:
        return 'Hủy';
      case GoalStatus.overdue:
        return 'Quá hạn';
    }
  }
}

