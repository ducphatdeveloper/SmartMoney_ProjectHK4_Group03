import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/saving_goal_provider.dart';
import 'detail_saving_goal_screen.dart';

class SavingGoalListView extends StatelessWidget {
  const SavingGoalListView({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,###", "vi_VN");

    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        if (provider.goals.isEmpty) {
          return const Center(child: Text("No goals found", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          itemCount: provider.goals.length,
          itemBuilder: (context, index) {
            final goal = provider.goals[index];
            final double progress = (goal.progressPercent ?? 0) / 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DetailSavingGoalScreen(goal: goal)),
                  );
                  if (result == true) {
                    provider.loadGoals();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(backgroundColor: Colors.orange, radius: 20, child: Icon(Icons.savings, color: Colors.white, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(goal.goalName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text("Remaining: ${currencyFormat.format(goal.remainingAmount)} đ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text("${(goal.progressPercent ?? 0).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress > 1 ? 1 : progress,
                          minHeight: 4, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}