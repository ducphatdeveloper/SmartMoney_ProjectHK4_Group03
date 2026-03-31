import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:smart_money/modules/saving_goal/providers/saving_goal_provider.dart';

class WalletListView extends StatelessWidget {
  const WalletListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Chỉ lắng nghe (Consumer) tại nơi thực sự cần hiển thị danh sách
    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {

        // 1. Trạng thái đang tải
        if (provider.isLoading && provider.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }

        // 2. Trạng thái trống
        if (provider.goals.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: Colors.grey, size: 50),
                SizedBox(height: 10),
                Text("Chưa có mục tiêu tiết kiệm nào", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // 3. Hiển thị danh sách
        return ListView.builder(
          shrinkWrap: true, // Giúp ListView hoạt động tốt bên trong Column
          physics: const NeverScrollableScrollPhysics(), // Để dùng chung scroll với màn hình chính nếu cần
          itemCount: provider.goals.length,
          itemBuilder: (context, index) {
            final goal = provider.goals[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.savings, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.goalName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Mục tiêu: ${NumberFormat("#,###").format(goal.targetAmount)} ${goal.currencyCode ?? 'VND'}",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${(goal.progressPercent ?? 0).toStringAsFixed(1)}%",
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      const Text("tiến độ", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
