import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/saving_goal_provider.dart';
import 'saving_goal_list_view.dart';
import '../../wallet/screens/add_wallet_type_screen.dart';

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
        elevation: 0,
        title: const Text("My Saving Wallets",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 28),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddWalletTypeScreen()),
              );
              if (result == true) _refreshData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Phần Card tổng tiền dùng chung style Gradient với item cũ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _totalBalanceCard(),
          ),
          const Expanded(
            child: SavingGoalListView(),
          ),
        ],
      ),
    );
  }

  Widget _totalBalanceCard() {
    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        double total = provider.goals.fold(0, (sum, item) => sum + item.currentAmount);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2C2C2E),
                Color(0xFF1C1C1E),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TOTAL SAVED",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${NumberFormat("#,###").format(total)} đ",
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                    ),
                  ),
                  const Icon(Icons.account_balance_wallet, color: Colors.greenAccent, size: 30),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}