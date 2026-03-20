
import 'package:flutter/material.dart';
import '../total_balance_card.dart';
import 'wallet_list_view.dart';
import '../../saving_goal/screens/saving_goal_list_view.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ví của tôi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            TotalBalanceCard(),
            SizedBox(height: 24),
            WalletListView(),
            SizedBox(height: 24),
            SavingGoalListView(),
          ],
        ),
      ),
    );
  }
}
