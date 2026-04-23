/// Nguồn gốc tạo giao dịch: manual, chat AI, voice, receipt, scheduled
enum TransactionSourceType {
  manual,   // 1 - Nhập thủ công
  chat,     // 2 - Chat AI
  voice,    // 3 - Giọng nói
  receipt,  // 4 - Quét hóa đơn
  planned;  // 5 - Giao dịch dự kiến

  int get value => index + 1;

  static TransactionSourceType fromValue(int value) {
    if (value < 1 || value > 5) {
      return TransactionSourceType.manual;
    }
    return TransactionSourceType.values[value - 1];
  }

  String get displayName {
    switch (this) {
      case TransactionSourceType.manual:
        return 'Manual entry';
      case TransactionSourceType.chat:
        return 'Chat AI';
      case TransactionSourceType.voice:
        return 'Voice';
      case TransactionSourceType.receipt:
        return 'Scan receipt';
      case TransactionSourceType.planned:
        return 'Scheduled transaction';
    }
  }
}

