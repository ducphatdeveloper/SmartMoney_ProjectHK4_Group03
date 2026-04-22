import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/token_helper.dart'; // Đảm bảo đúng path
import '../providers/saving_goal_provider.dart';
import 'saving_goal_list_view.dart';
import '../../wallet/screens/add_wallet_type_screen.dart';

class SavingGoalListScreen extends StatefulWidget {
  const SavingGoalListScreen({super.key});

  @override
  State<SavingGoalListScreen> createState() => SavingGoalListScreenState();
}

class SavingGoalListScreenState extends State<SavingGoalListScreen> {
  bool _isFinished = false;
  String? _accessToken; // Thêm biến lưu token

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // Lấy token giống EventScreen
  Future<void> _initData() async {
    final token = await TokenHelper.getAccessToken();
    if (mounted) {
      setState(() => _accessToken = token);
      // Load tab ban đầu (Active)
      context.read<SavingGoalProvider>().loadGoals(_isFinished, forceRefresh: true);
    }
  }

  void _refreshData() {
    // Gọi loadGoals với trạng thái tab hiện tại
    context.read<SavingGoalProvider>().loadGoals(_isFinished, forceRefresh: true);
  }

  void _changeTab(bool value) {
    if (_isFinished == value) return;
    setState(() => _isFinished = value);
    // Load lại data cho tab mới
    context.read<SavingGoalProvider>().loadGoals(_isFinished, forceRefresh: true);
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
              if (result == true) {
                // Sau khi thêm mới, luôn refresh lại tab Active
                _changeTab(false);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSegment(),

          // Kiểm tra nếu KHÔNG PHẢI Finished thì mới hiện Card
          if (!_isFinished)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _totalBalanceCard(),
            ),

          Expanded(
            child: (_accessToken == null)
                ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : SavingGoalListView(
              accessToken: _accessToken,
              isFinished: _isFinished,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Segment & Card giữ nguyên ---

  Widget _buildSegment() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      height: 50,
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16)
      ),
      child: Row(
        children: [
          _segmentItem("Active", !_isFinished, () => _changeTab(false)),
          _segmentItem("Finished", _isFinished, () => _changeTab(true)),
        ],
      ),
    );
  }

  Widget _segmentItem(String title, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive ? const Color(0xFF2C2C2E) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
                color: isActive ? Colors.greenAccent : Colors.grey,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w500
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalBalanceCard() {
    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        // Dữ liệu đã được lọc sẵn bởi provider.loadGoals(_isFinished)
        final goalsForCurrentTab = provider.goals;
        double total = goalsForCurrentTab.fold(0, (sum, item) => sum + item.currentAmount);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isFinished ? "TOTAL COLLECTED" : "TOTAL SAVED",
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
                    "${NumberFormat("#,###").format(total)} VND",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Icon(
                    _isFinished ? Icons.check_circle : Icons.account_balance_wallet,
                    color: Colors.greenAccent,
                    size: 30,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
