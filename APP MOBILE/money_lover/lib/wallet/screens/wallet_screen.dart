import 'package:flutter/material.dart';
import 'package:money_lover/wallet/screens/add_wallet_type_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Ví của tôi"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddWalletTypeScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _totalBalanceCard(),

          // ===== Ví tính vào tổng =====
          const SizedBox(height: 24),
          _sectionTitle("Ví tính vào tổng cộng"),

          _walletItem(
            icon: Icons.account_balance_wallet,
            name: "Tiền mặt",
            balance: "2,500,000 đ",
            color: Colors.green,
            included: true,
          ),
          _walletItem(
            icon: Icons.credit_card,
            name: "Ngân hàng",
            balance: "7,494,550,000 đ",
            color: Colors.blue,
            included: true,
          ),

          // ===== Ví không tính vào tổng =====
          const SizedBox(height: 24),
          _sectionTitle("Ví không tính vào tổng cộng"),

          _walletItem(
            icon: Icons.wallet,
            name: "Ví phụ",
            balance: "1,000,000 đ",
            color: Colors.grey,
            included: false,
          ),

          // ===== Ví tiết kiệm =====
          const SizedBox(height: 24),
          _sectionTitle("Ví tiết kiệm"),

          _savingWalletItem(
            icon: Icons.savings,
            name: "Mua xe",
            current: "5,000,000 đ",
            target: "50,000,000 đ",
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _totalBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Tổng cộng", style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            "9,994,550,000 đ",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _walletItem({
    required IconData icon,
    required String name,
    required String balance,
    required Color color,
    required bool included,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Icon(
                included ? Icons.check_circle : Icons.remove_circle_outline,
                size: 16,
                color: included ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Ví tiết kiệm =====
  Widget _savingWalletItem({
    required IconData icon,
    required String name,
    required String current,
    required String target,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$current / $target",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
