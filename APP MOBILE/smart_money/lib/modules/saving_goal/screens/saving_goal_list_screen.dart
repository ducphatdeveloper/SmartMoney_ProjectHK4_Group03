import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/saving_goal/providers/saving_goal_provider.dart';
import 'package:smart_money/modules/saving_goal/screens/saving_goal_list_view.dart';
import 'package:smart_money/modules/wallet/screens/add_wallet_type_screen.dart';

class SavingGoalListScreen extends StatefulWidget {
  const SavingGoalListScreen({super.key});

  @override
  State<SavingGoalListScreen> createState() => SavingGoalListScreenState();
}

class SavingGoalListScreenState extends State<SavingGoalListScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavingGoalProvider>().loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("My Saving Wallets", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddWalletTypeScreen()),
              );
              if (result == true) {
                _refreshData();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _totalBalanceCard(),
            const SizedBox(height: 20),
            const Expanded(
              child: SavingGoalListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalBalanceCard() {
    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        double total = provider.goals.fold(0, (sum, item) => sum + item.currentAmount);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Goal Savings", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                "${NumberFormat("#,###").format(total)} đ",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}