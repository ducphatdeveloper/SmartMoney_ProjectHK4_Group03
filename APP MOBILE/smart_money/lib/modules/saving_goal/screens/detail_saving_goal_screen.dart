import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../modules/transaction/providers/transaction_provider.dart';
import '../../../core/helpers/icon_helper.dart';
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
  final dateFmt = DateFormat('MMMM dd, yyyy');

  Map<String, dynamic> _getGoalStatusInfo(SavingGoalResponse goal) {
    final now = DateTime.now();
    final isFinished = goal.finished ?? false;
    final progress = goal.progressPercent ?? 0;

    if (progress >= 100) {
      return {"label": "COMPLETED", "color": Colors.greenAccent};
    }
    if (!isFinished && goal.endDate.isBefore(now) && progress < 100) {
      return {"label": "OVERDUE", "color": Colors.redAccent};
    }
    if (isFinished && progress < 100) {
      return {"label": "CANCELLED", "color": Colors.grey};
    }
    return {"label": "ACTIVE", "color": Colors.blueAccent};
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final progress = (goal.progressPercent ?? 0) / 100;
    final statusInfo = _getGoalStatusInfo(goal);
    final String currencyStr = goal.currencyCode ?? "VND";
    final bool isCompleted = (goal.progressPercent ?? 0) >= 100;
    final bool isFinished = goal.finished ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text("Goal Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditSavingGoalScreen(goal: goal)),
              );
              if (result == true && mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("Edit",
                style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            /// 🏆 HEADER CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2C2C2E),
                    const Color(0xFF1C1C1E).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isCompleted ? Colors.greenAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    width: 1
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  _buildAnimatedIcon(goal.imageUrl, isCompleted),
                  const SizedBox(height: 20),
                  Text(
                    goal.goalName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusChip(statusInfo['label'], statusInfo['color']),
                  const SizedBox(height: 32),
                  _buildFancyProgress(progress, isCompleted),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// 📊 FINANCIAL DETAILS
            _buildSectionTitle("Financial Overview"),
            _buildCard([
              _buildTile(Icons.track_changes, "Target Amount", "${fmt.format(goal.targetAmount)} $currencyStr", Colors.greenAccent),
              _buildDivider(),
              _buildTile(Icons.account_balance_wallet, "Current Balance", "${fmt.format(goal.currentAmount)} $currencyStr", Colors.blueAccent),
              _buildDivider(),
              _buildTile(Icons.money_off_rounded, "Remaining to Save", "${fmt.format(goal.remainingAmount)} $currencyStr", Colors.redAccent),
              _buildDivider(),
              _buildTile(Icons.currency_exchange, "Currency Unit", "VIET NAM DONG", Colors.amberAccent),
            ]),

            const SizedBox(height: 24),

            /// 📅 SETTINGS & SCHEDULE
            _buildSectionTitle("Settings & Schedule"),
            _buildCard([
              if (goal.beginDate != null) ...[
                _buildTile(Icons.calendar_month, "Start Date", dateFmt.format(goal.beginDate!), Colors.orangeAccent),
                _buildDivider(),
              ],
              _buildTile(Icons.event_available, "Deadline", dateFmt.format(goal.endDate), Colors.redAccent),
              _buildDivider(),
              _buildReadOnlySwitch(Icons.notifications_active_outlined, "Smart Notification", "Regular reminders", goal.notified ?? false, Colors.purpleAccent),
              _buildDivider(),
              _buildReadOnlySwitch(Icons.insights_rounded, "Show in Reports", "Include in analytics", goal.reportable ?? false, Colors.tealAccent),
            ]),

            const SizedBox(height: 30),

            /// 🔥 NEW: ACTION GROUP (Giống bên Event)
            _buildActionGroup([
              _buildActionItem(
                // Hiển thị text động dựa trên trạng thái hiện tại
                isFinished ? "Re-open Goal" : "Mark as Finished",
                isFinished ? Icons.history : Icons.check_circle_outline,
                isFinished ? Colors.blueAccent : Colors.greenAccent,
                    () async {
                  // 1. Hiển thị loading nhẹ (tùy chọn) hoặc gọi trực tiếp provider
                  final success = await context.read<SavingGoalProvider>().toggleStatus(goal.id);

                  if (success && mounted) {
                    // 2. Thông báo cho người dùng (tùy chọn)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isFinished ? "Goal re-opened!" : "Goal marked as finished!"),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 1),
                      ),
                    );

                    // 3. QUAN TRỌNG: Navigator.pop(context, true)
                    // Trả về 'true' để màn hình danh sách (ListScreen) biết và gọi loadGoals() cập nhật lại các tab
                    Navigator.pop(context, true);
                  } else if (mounted) {
                    // Xử lý khi lỗi
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.read<SavingGoalProvider>().errorMessage ?? "Action failed"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
              _buildDivider(indent: 56),
              _buildActionItem(
                "Transaction History",
                Icons.receipt_long_rounded,
                Colors.white,
                    () {
                  // Điều hướng đến danh sách giao dịch của goal này
                },
              ),
            ]),

            const SizedBox(height: 20),

            /// 🗑 DELETE BUTTON
            _buildActionItem(
                "Delete Goal",
                Icons.delete_outline_rounded,
                Colors.redAccent,
                _confirmDelete,
                isSingle: true
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildActionGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionItem(String title, IconData icon, Color color, VoidCallback onTap, {bool isSingle = false}) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );

    if (isSingle) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: content,
      );
    }
    return content;
  }

  Widget _buildAnimatedIcon(String? url, bool isCompleted) {
    return Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isCompleted
              ? [Colors.greenAccent, Colors.blueAccent]
              : [Colors.orangeAccent, Colors.redAccent],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle),
        child: IconHelper.buildCircleAvatar(iconUrl: url, radius: 38),
      ),
    );
  }

  Widget _buildFancyProgress(double progress, bool isCompleted) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isCompleted ? "Goal Completed 🎉" : "Progress",
                style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
            Text("${(progress * 100).toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
                height: 12,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10))
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: (MediaQuery.of(context).size.width - 72) * progress.clamp(0.0, 1.0),
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [Colors.greenAccent, Colors.tealAccent]
                      : [Colors.orangeAccent, Colors.deepOrange],
                ),
                boxShadow: [
                  BoxShadow(
                      color: (isCompleted ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.3),
                      blurRadius: 8
                  )
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(title.toUpperCase(),
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildTile(IconData icon, String label, String value, Color color) {
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)
      ),
      title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      trailing: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildReadOnlySwitch(IconData icon, String title, String subtitle, bool value, Color color) {
    return IgnorePointer(
      child: SwitchListTile(
        secondary: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        value: value,
        onChanged: (_) {},
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDivider({double indent = 55}) => Divider(height: 1, indent: indent, color: const Color(0xFF2C2C2E));

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Goal?", style: TextStyle(color: Colors.white)),
        content: const Text("All data related to this saving goal will be permanently removed.",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
              onPressed: () async {
                await context.read<SavingGoalProvider>().deleteGoal(widget.goal.id);
                if (context.mounted) {
                  context.read<TransactionProvider>().refreshSourceItems();
                }
                if (mounted) { Navigator.pop(ctx); Navigator.pop(context, true); }
              }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}