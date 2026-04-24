import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_constants.dart';
import '../../../modules/transaction/screens/common_transaction_list_screen.dart';
import '../models/event_response.dart';
import '../providers/event_provider.dart';
import 'edit_event_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final EventResponse event;
  final Function(bool)? onTabChanged;

  const EventDetailScreen({super.key, required this.event, this.onTabChanged});

  // --- Logic Helpers ---

  String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    final base = AppConstants.baseUrl.replaceAll("/api", "");
    if (url.startsWith("http")) return url;
    return "$base/images/$url";
  }

  String _formatFullVND(double amount) {
    return "${NumberFormat("#,###", "vi_VN").format(amount)} VND";
  }

  @override
  Widget build(BuildContext context) {
    bool isFinished = event.finished ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isFinished ? "Event Completed" : "Spending Analysis",
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!isFinished)
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditEventScreen(event: event)),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit_note, color: Colors.greenAccent),
            ),
        ],
      ),
      body: isFinished ? _buildFinishedUI(context) : _buildActiveUI(context),
    );
  }

  // --- GIAO DIỆN KHI ĐÃ HOÀN THÀNH (FINISHED) ---
  Widget _buildFinishedUI(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final iconUrl = _fixUrl(event.eventIconUrl);

    bool canReopen =
        event.endDate.isAfter(today) || event.endDate.isAtSameMomentAs(today);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blueAccent.withOpacity(0.5), Colors.tealAccent.withOpacity(0.5)],
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF0F0F0F), shape: BoxShape.circle),
                child: ClipOval(
                  child: iconUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 50),
                  )
                      : const Icon(Icons.event_available, color: Colors.greenAccent, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "MISSION ACCOMPLISHED!",
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "The event '${event.eventName}' has been closed successfully.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  const Text(
                    "FINAL NET BALANCE",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatFullVND(event.netAmount),
                    style: TextStyle(
                      color: event.netAmount >= 0
                          ? Colors.blueAccent
                          : Colors.orangeAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            _buildLargeButton(
              label: "CLOSE",
              color: Colors.white.withOpacity(0.05),
              textColor: Colors.white,
              onTap: () => Navigator.pop(context),
            ),
            if (canReopen) ...[
              const SizedBox(height: 16),
              _buildLargeButton(
                label: "RE-OPEN EVENT",
                color: Colors.greenAccent.withOpacity(0.1),
                textColor: Colors.greenAccent,
                icon: Icons.refresh,
                onTap: () => _confirmToggleStatus(context, "re-open", false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- GIAO DIỆN KHI ĐANG HOẠT ĐỘNG (ACTIVE) ---
  Widget _buildActiveUI(BuildContext context) {
    double budget = event.totalIncome;
    double spendingRatio = 0;
    bool isOverBudget = false;
    String healthMessage = "";

    if (budget > 0) {
      spendingRatio = event.totalExpense / budget;
      isOverBudget = spendingRatio > 1.0;
      healthMessage = isOverBudget
          ? "You have exceeded your allocated budget!"
          : "Spending is at ${(spendingRatio * 100).toStringAsFixed(1)}% of income.";
    } else {
      if (event.totalExpense > 0) {
        spendingRatio = 1.0;
        isOverBudget = true;
        healthMessage = "Warning: Spending with no income recorded!";
      } else {
        spendingRatio = 0;
        healthMessage = "No financial activity recorded yet.";
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(event),
          const SizedBox(height: 24),
          _buildSectionTitle("Budget Health"),
          _buildBudgetProgressCard(spendingRatio, isOverBudget, healthMessage),
          const SizedBox(height: 24),
          _buildSectionTitle("Financial Overview"),
          _buildMetricsGrid(event),
          const SizedBox(height: 24),
          _buildSectionTitle("Operations"),
          _buildActionTile(
            title: "View Transactions",
            subtitle: "Deep dive into every record",
            icon: Icons.analytics_outlined,
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommonTransactionListScreen(
                  title: event.eventName,
                  filters: {'eventId': event.id.toString()},
                ),
              ),
            ),
          ),
          _buildActionTile(
            title: "Complete Event",
            subtitle: "Close this event and see final results",
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent,
            onTap: () => _confirmToggleStatus(context, "complete", true),
          ),
          _buildActionTile(
            title: "Delete Analysis",
            subtitle: "Permanently remove event data",
            icon: Icons.delete_sweep_outlined,
            color: Colors.redAccent,
            onTap: () => _showDeleteConfirm(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- HỘP THOẠI XÁC NHẬN HOÀN THÀNH / MỞ LẠI ---
  void _confirmToggleStatus(BuildContext context, String action, bool targetStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${action[0].toUpperCase()}${action.substring(1)} Event?",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to $action this event?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<EventProvider>(context, listen: false);
              await provider.toggleStatus(event.id);
              if (onTabChanged != null) onTabChanged!(targetStatus);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(
              action.toUpperCase(),
              style: TextStyle(
                color: action == "complete" ? Colors.greenAccent : Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(EventResponse event) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Total Income",
                _formatFullVND(event.totalIncome),
                Colors.greenAccent,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                "Total Expense",
                _formatFullVND(event.totalExpense),
                Colors.redAccent,
                Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Net Balance",
                _formatFullVND(event.netAmount),
                event.netAmount >= 0 ? Colors.blueAccent : Colors.orangeAccent,
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                "Days Left",
                _getDaysLeft(event.endDate),
                Colors.purpleAccent,
                Icons.timer_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.03))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildLargeButton({
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: textColor.withOpacity(0.1)),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(EventResponse event) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white10,
          backgroundImage: _fixUrl(event.eventIconUrl).isNotEmpty
              ? CachedNetworkImageProvider(_fixUrl(event.eventIconUrl))
              : null,
          child: _fixUrl(event.eventIconUrl).isEmpty
              ? const Icon(Icons.event, color: Colors.greenAccent)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.eventName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                "${DateFormat('dd/MM').format(event.beginDate ?? DateTime.now())} - ${DateFormat('dd/MM/yyyy').format(event.endDate)}",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
        ),
        _buildStatusBadge(event.finished ?? false),
      ],
    );
  }

  Widget _buildBudgetProgressCard(double ratio, bool isOver, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: isOver
            ? Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Spending Progress",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                isOver ? "OVER BUDGET" : "${(ratio * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                    color: isOver ? Colors.redAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white10,
              color: isOver ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(isOver ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: isOver ? Colors.redAccent : Colors.white38, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: isOver
                            ? Colors.redAccent.withOpacity(0.9)
                            : Colors.white54,
                        fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      {required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        tileColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle:
        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1)),
    );
  }

  Widget _buildStatusBadge(bool finished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: finished ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: finished
                ? Colors.blueAccent.withOpacity(0.4)
                : Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Text(finished ? "FINISHED" : "ACTIVE",
          style: TextStyle(
              color: finished ? Colors.blueAccent : Colors.greenAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold)),
    );
  }

  String _getDaysLeft(DateTime endDate) {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? "Expired" : "$diff Days";
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Analysis?", style: TextStyle(color: Colors.white)),
        content: const Text("All event data will be removed. This cannot be undone.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Provider.of<EventProvider>(context, listen: false).delete(event.id);
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}