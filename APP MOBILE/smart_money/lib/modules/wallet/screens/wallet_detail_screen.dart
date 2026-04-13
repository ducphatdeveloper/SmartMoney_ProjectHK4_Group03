import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/icon_helper.dart';
import '../../../modules/transaction/providers/transaction_provider.dart';
import '../../budget/screens/budget_screens.dart';
import '../models/wallet_response.dart';
import '../providers/wallet_provider.dart';
import 'edit_wallet_screen.dart';

class WalletDetailScreen extends StatefulWidget {
  final WalletResponse wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late bool excludeFromTotal;
  bool notification = false;

  @override
  void initState() {
    super.initState();
    excludeFromTotal = !(widget.wallet.reportable ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditWalletScreen(wallet: wallet),
                ),
              );

              if (result == true) {
                Provider.of<WalletProvider>(context, listen: false)
                    .loadAll();
                Navigator.pop(context);
              }
            },
            child: const Text("Sửa"),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _mainCard(wallet),
          const SizedBox(height: 20),
          // _switchTile(
          //   title: "Bật thông báo",
          //   subtitle: "Nhận thông báo khi ví có giao dịch mới.",
          //   value: notification,
          //   onChanged: (v) => setState(() => notification = v),
          // ),
          // const SizedBox(height: 10),
          // _switchTile(
          //   title: "Không tính vào tổng",
          //   subtitle: 'Bỏ qua ví này khỏi "Tổng".',
          //   value: excludeFromTotal,
          //   onChanged: (v) => setState(() => excludeFromTotal = v),
          // ),
          const SizedBox(height: 30),
          _deleteButton(context),
        ],
      ),
    );
  }

  // ================= FORMAT MONEY =================

  String formatVND(double amount) {
    String value = amount.toInt().toString();

    final result = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );

    return "$result đ";
  }

  // ================= UI =================

  Widget _mainCard(WalletResponse wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2C2C2E),
            Color(0xFF1C1C1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          /// ICON + NAME
          Row(
            children: [
              IconHelper.buildCircleAvatar(
                iconUrl: wallet.goalImageUrl,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  wallet.walletName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// BALANCE
          Text(
            formatVND(wallet.balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Số dư hiện tại",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 20),

          const Divider(color: Colors.grey, height: 1),

          const SizedBox(height: 12),

          /// CURRENCY
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.attach_money, color: Colors.grey, size: 18),
              SizedBox(width: 6),
              Text(
                "Việt Nam Đồng",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: _card(),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _deleteButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () => _confirmDelete(context),
      child: const Text(
        "Delete Wallet",
        style: TextStyle(color: Colors.red, fontSize: 16),
      ),
    );
  }

  BoxDecoration _card() => BoxDecoration(
    color: const Color(0xFF1C1C1E),
    borderRadius: BorderRadius.circular(20),
  );

  // ================= ACTION =================

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Xóa ví"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bạn có chắc chắn muốn xóa ví này không?",
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),

            const Text(
              "Nếu xóa, toàn bộ ngân sách liên quan đến ví này có thể bị ảnh hưởng.",
              style: TextStyle(color: Colors.redAccent),
            ),

            const SizedBox(height: 12),

            // 🔗 LINK XEM BUDGET
            GestureDetector(
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BudgetScreen(
                      initialWallet: widget.wallet, // truyền id qua
                    ),
                  ),
                );
              },
              child: const Text(
                "Xem ngân sách liên quan",
                style: TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              final provider =
              Provider.of<WalletProvider>(context, listen: false);

              await provider.deleteWallet(widget.wallet.id);

              // refresh transaction
              if (context.mounted) {
                context.read<TransactionProvider>().refreshSourceItems();
              }

              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text(
              "Xóa",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}