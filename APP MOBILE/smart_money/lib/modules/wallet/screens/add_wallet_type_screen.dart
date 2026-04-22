  import 'package:flutter/material.dart';
  import 'package:smart_money/modules/wallet/screens/add_basic_wallet_screen.dart';
  import 'package:smart_money/modules/saving_goal/screens/add_saving_goal_screen.dart';

  class AddWalletTypeScreen extends StatelessWidget {
    const AddWalletTypeScreen({super.key});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Add Wallet"),
          centerTitle: true,
          backgroundColor: Colors.black,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 2,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 140, // 🔥 CHIỀU CAO CHUẨN (quan trọng nhất)
            ),
            itemBuilder: (context, index) {
              final items = [
                {
                  "title": "Basic Wallet",
                  "color1": const Color(0xFF34C759),
                  "color2": const Color(0xFF2DBE60),
                  "icon": Icons.account_balance_wallet,
                  "screen": const AddBasicWalletScreen(),
                },
                {
                  "title": "Savings Wallet",
                  "color1": const Color(0xFFFF5F6D),
                  "color2": const Color(0xFFFF3B30),
                  "icon": Icons.savings,
                  "screen": const AddSavingGoalScreen(),
                },
              ];

              final item = items[index];

              return _card(
                title: item["title"] as String,
                color1: item["color1"] as Color,
                color2: item["color2"] as Color,
                icon: item["icon"] as IconData,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => item["screen"] as Widget,
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    }

    Widget _card({
      required String title,
      required Color color1,
      required Color color2,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [

              // ICON BACKGROUND (đẹp hơn)
              Positioned(
                bottom: -5,
                right: -5,
                child: Icon(
                  icon,
                  size: 60, // 🔥 chuẩn
                  color: Colors.white.withOpacity(0.12),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // dấu ?
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            "?",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }