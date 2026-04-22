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

  // Định dạng số tiền: 1.000.000.000.000 VND

  String _formatFullVND(double amount) {
    final formatter = NumberFormat("#,###", "vi_VN");

    return "${formatter.format(amount)} VND";
  }

  @override
  Widget build(BuildContext context) {
    // Ngân sách giả định để tính tỷ lệ biểu đồ

    double budget = event.totalIncome > 0
        ? event.totalIncome
        : (event.totalExpense * 1.5);

    if (budget == 0) budget = 100000;

    double spendingRatio = event.totalExpense / budget;

    bool isOverBudget = spendingRatio > 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),

          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          "Spending Analysis",

          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (_) => EditEventScreen(event: event),
                ),
              );

              if (result == true && context.mounted)
                Navigator.pop(context, true);
            },

            icon: const Icon(Icons.edit_note, color: Colors.greenAccent),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildHeaderSection(event),

            const SizedBox(height: 24),

            _buildSectionTitle("Budget Health"),

            _buildBudgetProgressCard(spendingRatio, isOverBudget),

            const SizedBox(height: 24),

            _buildSectionTitle("Financial Distribution"),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),

              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),

                borderRadius: BorderRadius.circular(24),

                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),

              child: Row(
                children: [
                  Expanded(
                    child: _buildAnalysisCircle(
                      label: "Income",

                      amount: event.totalIncome,

                      total: budget,

                      color: Colors.greenAccent,
                    ),
                  ),

                  Expanded(
                    child: _buildAnalysisCircle(
                      label: "Expense",

                      amount: event.totalExpense,

                      total: budget,

                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle("Key Metrics"),

            _buildMetricsRow(event),

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
              title: event.finished == true
                  ? "Re-open Event"
                  : "Complete Event",

              subtitle: event.finished == true
                  ? "Restore to active status"
                  : "Archive this analysis",

              icon: event.finished == true
                  ? Icons.refresh
                  : Icons.check_circle_outline,

              color: Colors.tealAccent,

              onTap: () async {
                final provider = Provider.of<EventProvider>(
                  context,
                  listen: false,
                );

                await provider.toggleStatus(event.id);

                if (onTabChanged != null)
                  onTabChanged!(!(event.finished ?? false));

                if (context.mounted) Navigator.pop(context, true);
              },
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
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildAnalysisCircle({
    required String label,

    required double amount,

    required double total,

    required Color color,
  }) {
    double percent = total > 0 ? (amount / total) : 0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,

          children: [
            SizedBox(
              width: 90,
              height: 90,

              child: CircularProgressIndicator(
                value: 1.0,

                strokeWidth: 6,

                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            SizedBox(
              width: 90,
              height: 90,

              child: CircularProgressIndicator(
                value: percent.clamp(0.0, 1.0),

                strokeWidth: 7,

                strokeCap: StrokeCap.round,

                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),

            Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  "${(percent * 100).toInt()}%",

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  label.toUpperCase(),

                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Chống tràn layout cho số tiền cực lớn
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),

          child: FittedBox(
            fit: BoxFit.scaleDown,

            child: Text(
              _formatFullVND(amount),

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(EventResponse event) {
    return Row(
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
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: color, size: 20),

          const SizedBox(height: 10),

          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),

          const SizedBox(height: 4),

          // Scale số tiền xuống nếu quá dài để không nhảy dòng hoặc vỡ box
          SizedBox(
            width: double.infinity,

            child: FittedBox(
              fit: BoxFit.scaleDown,

              alignment: Alignment.centerLeft,

              child: Text(
                value,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CÁC WIDGET CƠ BẢN ---

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
              Text(
                event.eventName,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                "${DateFormat('dd/MM').format(event.beginDate ?? DateTime.now())} - ${DateFormat('dd/MM/yyyy').format(event.endDate)}",

                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        _buildStatusBadge(event.finished ?? false),
      ],
    );
  }

  Widget _buildBudgetProgressCard(double ratio, bool isOver) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              const Text(
                "Spending Progress",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),

              Text(
                "${(ratio * 100).toStringAsFixed(1)}%",

                style: TextStyle(
                  color: isOver ? Colors.redAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),

              minHeight: 6,

              backgroundColor: Colors.white10,

              color: isOver ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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
            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(icon, color: color, size: 22),
        ),

        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),

        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),

        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white24,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),

      child: Text(
        title.toUpperCase(),

        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool finished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: finished
            ? Colors.blue.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),

        borderRadius: BorderRadius.circular(6),

        border: Border.all(
          color: finished
              ? Colors.blueAccent.withOpacity(0.4)
              : Colors.greenAccent.withOpacity(0.4),
        ),
      ),

      child: Text(
        finished ? "FINISHED" : "ACTIVE",

        style: TextStyle(
          color: finished ? Colors.blueAccent : Colors.greenAccent,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
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

        title: const Text(
          "Delete Analysis?",
          style: TextStyle(color: Colors.white),
        ),

        content: const Text(
          "All event data will be removed. This cannot be undone.",

          style: TextStyle(color: Colors.white70),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () {
              Provider.of<EventProvider>(
                context,
                listen: false,
              ).delete(event.id);

              Navigator.pop(ctx);

              Navigator.pop(context, true);
            },

            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
