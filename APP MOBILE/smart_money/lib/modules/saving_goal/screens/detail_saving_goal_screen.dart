import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/saving_goal_response.dart';
import '../providers/saving_goal_provider.dart';
import 'edit_saving_goal_screen.dart';

class DetailSavingGoalScreen extends StatefulWidget {
  final SavingGoalResponse goal;
  const DetailSavingGoalScreen({super.key, required this.goal});

  @override
  State<DetailSavingGoalScreen> createState() => _DetailSavingGoalScreenState();
}

class _DetailSavingGoalScreenState extends State<DetailSavingGoalScreen> {
  final fmt = NumberFormat("#,###", "vi_VN");

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final progress = (goal.progressPercent ?? 0) / 100;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Goal Details"),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSavingGoalScreen(goal: goal))),
            child: const Text("Edit", style: TextStyle(color: Colors.blue, fontSize: 18)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const CircleAvatar(backgroundColor: Colors.orange, radius: 30, child: Icon(Icons.savings, size: 35, color: Colors.white)),
                  const SizedBox(height: 15),
                  Text(goal.goalName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${goal.progressPercent?.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text("${fmt.format(goal.currentAmount)} / ${fmt.format(goal.targetAmount)} đ", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress > 1 ? 1 : progress, backgroundColor: Colors.white10, color: Colors.green, minHeight: 8),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _actionButton("Deposit Savings", Colors.green, () => _showDepositDialog()),
            const SizedBox(height: 12),
            _actionButton("Delete Goal", Colors.red, () => _confirmDelete()),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  void _showDepositDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Deposit", style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: "Enter amount", hintStyle: TextStyle(color: Colors.grey))
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () async {
            await context.read<SavingGoalProvider>().depositMoney(widget.goal.id, double.tryParse(ctrl.text) ?? 0);
            if (mounted) { Navigator.pop(ctx); Navigator.pop(context, true); }
          }, child: const Text("Confirm")),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Confirm Delete?", style: TextStyle(color: Colors.white)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () async {
            await context.read<SavingGoalProvider>().deleteGoal(widget.goal.id);
            if (mounted) { Navigator.pop(ctx); Navigator.pop(context, true); }
          }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}