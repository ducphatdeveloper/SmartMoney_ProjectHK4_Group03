import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../models/event_response.dart';
import '../providers/event_provider.dart';
import 'edit_event_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final EventResponse event;

  const EventDetailScreen({super.key, required this.event});

  // 🔥 Helper xử lý URL ảnh
  String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    final base = AppConstants.baseUrl.replaceAll("/api", "");
    if (url.startsWith("http://") || url.startsWith("https://")) {
      if (url.contains(":8080") && !url.contains(":8080/")) {
        return url.replaceFirst(":8080", ":8080/");
      }
      return url;
    }
    return "$base/images/$url";
  }

  String _getDaysLeft(DateTime? endDate) {
    if (endDate == null) return "";
    final now = DateTime.now();
    final difference = endDate.difference(now).inDays;
    if (difference < 0) return "Expired";
    if (difference == 0) return "Ends today";
    return "Ends in $difference days";
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: event.currencyCode ?? 'VND',
      decimalDigits: 0,
    );

    final String startDate = event.beginDate != null
        ? DateFormat('dd/MM/yyyy').format(event.beginDate!)
        : "N/A";
    final String endDate = DateFormat('dd/MM/yyyy').format(event.endDate);
    final iconUrl = _fixUrl(event.eventIconUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Event Detail",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditEventScreen(event: event)),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("Edit",
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- 🔥 EVENT INFO CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: event.finished == true
                            ? [Colors.blueAccent, Colors.tealAccent]
                            : [Colors.greenAccent, Colors.blueAccent],
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Color(0xFF1C1C1E), shape: BoxShape.circle),
                      child: ClipOval(
                        child: iconUrl.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.event,
                              color: Colors.greenAccent,
                              size: 40),
                        )
                            : const Icon(Icons.event,
                            color: Colors.greenAccent, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    event.eventName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (event.finished == true ? Colors.blue : Colors.green)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.finished == true ? "FINISHED" : "ACTIVE",
                      style: TextStyle(
                          color: event.finished == true
                              ? Colors.blueAccent
                              : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(color: Color(0xFF3A3A3C), thickness: 1),
                  ),

                  // Hiển thị thời gian
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    "Timeline",
                    "$startDate - $endDate",
                    rightLabel: _getDaysLeft(event.endDate),
                  ),

                  const SizedBox(height: 20),

                  // --- FINANCIAL DATA SECTION ---
                  Row(
                    children: [
                      _buildFinanceBox("Income", event.totalIncome, Colors.greenAccent, currencyFormat),
                      const SizedBox(width: 12),
                      _buildFinanceBox("Expense", event.totalExpense, Colors.redAccent, currencyFormat),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFinanceBox("Net Balance", event.netAmount, Colors.orangeAccent, currencyFormat, isFullWidth: true),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- ACTION BUTTONS ---
            _buildActionGroup([
              _buildActionItem(
                  event.finished == true ? "Re-open Event" : "Mark as finished",
                  event.finished == true ? Icons.history : Icons.check_circle_outline,
                  event.finished == true ? Colors.blueAccent : Colors.greenAccent,
                      () {
                    Provider.of<EventProvider>(context, listen: false).toggleStatus(event.id);
                    Navigator.pop(context, true);
                  }),
              _buildActionItem(
                  "Transaction History",
                  Icons.receipt_long_rounded,
                  Colors.white,
                      () { /* Navigate to book */ }),
            ]),

            const SizedBox(height: 20),

            _buildActionItem(
                "Delete Event",
                Icons.delete_outline_rounded,
                Colors.redAccent,
                    () => _showDeleteConfirm(context),
                isSingle: true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String subTitle, {String? rightLabel}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.5), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 2),
              Text(subTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (rightLabel != null)
          Text(rightLabel, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFinanceBox(String label, double amount, Color color, NumberFormat format, {bool isFullWidth = false}) {
    return Expanded(
      flex: isFullWidth ? 0 : 1,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              format.format(amount),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

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

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: const Text("Delete Event",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            "All data related to this event will be permanently removed.",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.blueAccent))),
          TextButton(
            onPressed: () {
              Provider.of<EventProvider>(context, listen: false).delete(event.id);
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}