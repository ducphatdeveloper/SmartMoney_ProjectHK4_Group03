import 'package:flutter/material.dart';
import 'package:money_lover/wallet/screens/add_basic_wallet_screen.dart';
import 'package:money_lover/wallet/screens/add_saving_goal_screen.dart';

class AddWalletTypeScreen extends StatelessWidget {
  const AddWalletTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm ví"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _option(
              context,
              icon: Icons.account_balance_wallet,
              title: "Ví cơ bản",
              subtitle: "Dùng cho thu chi hằng ngày",
              color: Colors.blue,
              onTap: () {
                var push = Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddBasicWalletScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _option(
              context,
              icon: Icons.savings,
              title: "Ví tiết kiệm",
              subtitle: "Dùng cho mục tiêu tiết kiệm",
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSavingGoalScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
