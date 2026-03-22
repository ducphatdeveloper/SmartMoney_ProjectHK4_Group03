// modules/transaction/models/source_item.dart
// Item trong dropdown chọn ví/mục tiêu (Tổng cộng, Ví 1, Ví 2, Mục tiêu 1...)

class SourceItem {
  final int? id;
  final String name;
  final String type; // 'all' | 'wallet' | 'saving_goal'
  final String? iconUrl;
  double? balance; // Số dư hiển thị trong dropdown - mutable để có thể update

  SourceItem({
    required this.id,
    required this.name,
    required this.type,
    this.iconUrl,
    this.balance,
  });

  // Tạo item "Tổng cộng" (all sources)
  factory SourceItem.all() {
    return SourceItem(
      id: null,
      name: "Tổng cộng",
      type: 'all',
      iconUrl: null,
      balance: null,
    );
  }

  // Tạo item từ Wallet
  factory SourceItem.fromWallet({
    required int id,
    required String name,
    String? iconUrl,
    double? balance,
  }) {
    return SourceItem(
      id: id,
      name: name,
      type: 'wallet',
      iconUrl: iconUrl,
      balance: balance,
    );
  }

  // Tạo item từ SavingGoal
  factory SourceItem.fromSavingGoal({
    required int id,
    required String name,
    String? iconUrl,
    double? balance,
  }) {
    return SourceItem(
      id: id,
      name: name,
      type: 'saving_goal',
      iconUrl: iconUrl,
      balance: balance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SourceItem &&
        other.id == id &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, type);
}

