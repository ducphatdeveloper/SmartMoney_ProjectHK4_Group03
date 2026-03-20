import 'package:flutter/material.dart';
import 'package:smart_money/modules/wallet/screens/add_wallet_type_screen.dart';
import 'package:smart_money/modules/wallet/screens/wallet_list_view.dart';


class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {

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
                MaterialPageRoute(
                  builder: (_) => const AddWalletTypeScreen(),
                ),
              );

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
              child: WalletListView(),
            ),

          ],
        ),
      ),
    );
  }

  Widget _totalBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            "Tổng cộng",
            style: TextStyle(color: Colors.grey),
          ),

          SizedBox(height: 8),

          Text(
            "0 đ",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );
  }
}