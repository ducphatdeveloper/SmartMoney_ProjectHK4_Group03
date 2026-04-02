import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_money/widgets/chart_card.dart';
import 'package:smart_money/widgets/summary_card.dart';
import 'package:smart_money/modules/notification/providers/notification_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  bool isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    // Lấy số lượng thông báo chưa đọc ngay khi vào trang chủ
    Future.microtask(() => context.read<NotificationProvider>().fetchUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Làm mới toàn bộ dữ liệu
            await context.read<NotificationProvider>().fetchUnreadCount();
            // Có thể thêm fetchTransactions() hoặc fetchBalance() ở đây
          },
          color: Colors.blueAccent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildWalletCard(),
                const SizedBox(height: 24),
                _buildMonthFilter(),
                const SizedBox(height: 20),
                const SummaryCard(),
                const SizedBox(height: 24),
                const ChartCard(),
                const SizedBox(height: 30),
                _buildRecentTransactionsHeader(),
                const SizedBox(height: 10),
                _buildRecentTransactionsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            "SmartMoney",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
            _buildNotificationBell(context),
          ],
        )
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notiProvider, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () async {
                await context.push('/notifications');
                if (context.mounted) {
                  context.read<NotificationProvider>().fetchUnreadCount();
                }
              },
            ),
            if (notiProvider.unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    notiProvider.unreadCount > 99 ? "99+" : "${notiProvider.unreadCount}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
          ],
        );
      },
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff4facfe), Color(0xff00f2fe)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff4facfe).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ví chính", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isBalanceHidden ? "••••••••" : "9,994,550,000 đ",
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => setState(() => isBalanceHidden = !isBalanceHidden),
                icon: Icon(
                  isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMonthFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text("Tháng 3 / 2026", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey)
      ],
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return const Text("Giao dịch gần đây", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildRecentTransactionsList() {
    // Dữ liệu mock, sau này nên lấy từ TransactionProvider
    final transactions = [
      {"title": "Ăn uống", "date": "Hôm nay", "amount": "-50,000 đ", "color": Colors.orange, "icon": Icons.fastfood},
      {"title": "Xăng xe", "date": "Hôm qua", "amount": "-40,000 đ", "color": Colors.blue, "icon": Icons.directions_car},
      {"title": "Mua sắm", "date": "20/03", "amount": "-200,000 đ", "color": Colors.green, "icon": Icons.shopping_bag},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: (tx['color'] as Color).withOpacity(0.2),
            child: Icon(tx['icon'] as IconData, color: tx['color'] as Color),
          ),
          title: Text(tx['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(tx['date'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: Text(
            tx['amount'] as String,
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}