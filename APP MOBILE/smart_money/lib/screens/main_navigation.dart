import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modules/budget/providers/budget_provider.dart';
import '../modules/wallet/providers/wallet_provider.dart';
import 'home_screen.dart';
import 'package:smart_money/modules/transaction/screens/transaction_list_screen.dart';
import 'package:smart_money/modules/transaction/screens/transaction_create_screen.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/budget/screens/budget_screens.dart';
import 'account_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final int timestamp; // Dùng timestamp để nhận biết sự thay đổi từ Router
  const MainNavigation({super.key, this.initialIndex = 0, this.timestamp = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  // Cập nhật lại index khi widget nhận được tham số mới từ Router
  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Luôn cập nhật index nếu timestamp thay đổi (kể cả khi initialIndex giống nhau)
    if (widget.timestamp != oldWidget.timestamp) {
      setState(() {
        index = widget.initialIndex;
      });
    }
  }

  Widget _buildScreen() {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const TransactionListScreen();
      case 2:
        return const SizedBox();
      case 3:
      // Dùng Consumer để chắc chắn BudgetProvider có sẵn
        return const BudgetScreen();
      case 4:
        return const AccountScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          key: ValueKey("$index-${widget.timestamp}"), // Thêm timestamp vào key để switcher nhận biết
          child: _buildScreen(),
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: Colors.green,
      //   elevation: 8,
      //   onPressed: () async {
      //     final txProvider = context.read<TransactionProvider>();
      //     final currentSource = txProvider.selectedSource;
      //
      //     final result = await Navigator.push<bool>(
      //       context,
      //       MaterialPageRoute(builder: (_) => TransactionCreateScreen(
      //         initialSourceItem: currentSource,
      //       )),
      //     );
      //
      //     if (result == true && mounted) {
      //       // 👉 Chỉ reload BudgetProvider nếu user đang ở tab Budget
      //       // Tránh reload liên tục khi user đang ở tab khác
      //       if (index == 3) {
      //         final budgetProvider = context.read<BudgetProvider>();
      //         if (budgetProvider.selectedWalletId != null) {
      //           await budgetProvider.refreshAllData();
      //         }
      //       }
      //     }
      //   },
      //   child: const Icon(Icons.add, size: 28),
      // ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: BottomAppBar(
            color: Colors.black.withOpacity(0.85),
            shape: const CircularNotchedRectangle(),
            notchMargin: 6,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildItem(Icons.home, "Home", 0),
                        buildItem(Icons.list, "Transactions", 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildAddButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildItem(Icons.account_balance_wallet, "Budget", 3),
                        buildItem(Icons.person, "Account", 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildItem(IconData icon, String label, int itemIndex) {
    bool selected = index == itemIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          index = itemIndex;
        });

        // 👉 Reload BudgetProvider khi switch về tab Budget
        // Giải quyết vấn đề Budget không load lại khi quay lại từ màn hình khác
        if (itemIndex == 3) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final budgetProvider = context.read<BudgetProvider>();
            if (budgetProvider.selectedWalletId != null) {
              budgetProvider.refreshAllData();
            }
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.green : Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            width: selected ? 20 : 0,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: GestureDetector(
        onTap: () async {
          final txProvider = context.read<TransactionProvider>();
          final currentSource = txProvider.selectedSource;

          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionCreateScreen(
                initialSourceItem: currentSource,
              ),
            ),
          );

          if (result == true && mounted) {
            // Reload TransactionProvider, WalletProvider, and BudgetProvider
            final futures = <Future<void>>[
              context.read<TransactionProvider>().refresh(context),
              context.read<WalletProvider>().loadAll(context),
            ];
            if (index == 3) {
              futures.add(context.read<BudgetProvider>().refreshAllData());
            }
            await Future.wait(futures);
          }
        },
        child: Material(
          color: Colors.green,
          shape: const CircleBorder(),
          elevation: 8,
          child: const SizedBox(
            height: 52,
            width: 52,
            child: Icon(Icons.add, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }

}
