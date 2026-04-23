/// Loại thông báo: Giao dịch, Tiết kiệm, Ngân sách, Hệ thống, Chat AI, Ví, Sự kiện, Nợ/Vay, Nhắc nhở
enum NotificationType {
  transaction,  // 1 - Giao dịch / Biến động số dư
  saving,       // 2 - Mục tiêu tiết kiệm / Quỹ
  budget,       // 3 - Cảnh báo ngân sách
  system,       // 4 - Hệ thống / Cập nhật
  chatAi,       // 5 - Thông báo từ AI
  wallets,      // 6 - Thông báo ví / số dư âm
  events,       // 7 - Sự kiện / Lịch trình
  debtLoan,     // 8 - Nhắc nợ / Thu nợ
  reminder;     // 9 - Nhắc nhở chung

  int get value => index + 1;

  static NotificationType fromValue(int value) {
    if (value < 1 || value > 9) {
      return NotificationType.system;
    }
    return NotificationType.values[value - 1];
  }

  String get displayName {
    switch (this) {
      case NotificationType.transaction:
        return 'Transaction';
      case NotificationType.saving:
        return 'Savings';
      case NotificationType.budget:
        return 'Budget';
      case NotificationType.system:
        return 'System';
      case NotificationType.chatAi:
        return 'Chat AI';
      case NotificationType.wallets:
        return 'Wallet';
      case NotificationType.events:
        return 'Event';
      case NotificationType.debtLoan:
        return 'Debt/Loan';
      case NotificationType.reminder:
        return 'Reminder';
    }
  }
}

