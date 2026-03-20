import 'dart:ui';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'package:smart_money/modules/Transaction/screens/transaction_screens.dart';
import 'package:smart_money/modules/Transfer_transaction/screens/add_transaction_screens.dart';
import 'package:smart_money/modules/Budget/screens/budget_screens.dart';
import 'account_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {

  int index = 0;

  final screens = const [
    HomeScreen(),
    TransactionBookScreen(transactions: []),
    AddTransactionView(),
    BudgetScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      /// BODY ANIMATION
      body: AnimatedSwitcher(

        duration: const Duration(milliseconds: 350),

        transitionBuilder: (child, animation) {

          final slide = Tween<Offset>(
            begin: const Offset(0.1, 0),
            end: Offset.zero,
          ).animate(animation);

          return SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },

        child: KeyedSubtree(
          key: ValueKey(index),
          child: screens[index],
        ),
      ),

      /// FLOATING BUTTON
      floatingActionButton: FloatingActionButton(

        backgroundColor: Colors.green,
        elevation: 8,

        onPressed: () {
          setState(() {
            index = 2;
          });
        },

        child: const Icon(
          Icons.add,
          size: 28,
        ),
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,

      /// GLASS NAV BAR
      bottomNavigationBar: Container(

        margin: const EdgeInsets.all(12),

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(20),

          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
            )
          ],
        ),

        child: ClipRRect(

          borderRadius: BorderRadius.circular(20),

          child: BackdropFilter(

            filter: ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
            ),

            child: BottomAppBar(

              color: Colors.black.withOpacity(0.85),

              shape: const CircularNotchedRectangle(),

              notchMargin: 8,

              child: SizedBox(

                height: 65,

                child: Row(

                  mainAxisAlignment: MainAxisAlignment.spaceAround,

                  children: [

                    buildItem(Icons.home, "Tổng quan", 0),

                    buildItem(Icons.list, "Sổ giao dịch", 1),

                    const SizedBox(width: 40),

                    buildItem(Icons.account_balance_wallet, "Ngân sách", 3),

                    buildItem(Icons.person, "Tài khoản", 4),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  /// NAV ITEM
  Widget buildItem(
      IconData icon,
      String label,
      int itemIndex,
      ) {
    bool selected = index == itemIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          index = itemIndex;
        });
      },

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// ICON
          AnimatedScale(

            scale: selected ? 1.25 : 1,

            duration: const Duration(milliseconds: 200),

            child: Icon(
              icon,
              color: selected ? Colors.green : Colors.grey,
              size: 24,
            ),
          ),

          const SizedBox(height: 4),

          /// TEXT
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.green : Colors.grey,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 4),

          /// INDICATOR
          AnimatedContainer(

            duration: const Duration(milliseconds: 250),

            height: 3,
            width: selected ? 20 : 0,

            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
          )
        ],
      ),
    );
  }
}