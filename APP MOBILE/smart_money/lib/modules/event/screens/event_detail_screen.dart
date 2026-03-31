import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Thêm thư viện này để format ngày
import 'package:smart_money/modules/event/screens/edit_event_screen.dart';
import '../models/event_response.dart';
import '../providers/event_provider.dart';

class EventDetailScreen extends StatelessWidget {
  final EventResponse event;

  const EventDetailScreen({super.key, required this.event});

  // Hàm hỗ trợ tính toán số ngày còn lại
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
    // Format ngày sang String (ví dụ: 29/03/2026)
    // Nếu event.endDate là String sẵn thì không cần .toLocal(),
    // nhưng nếu là DateTime thì phải format như dưới đây:
    final String formattedDate = event.endDate != null
        ? DateFormat('dd/MM/yyyy').format(event.endDate as DateTime)
        : "No date set";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
            "Event",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
        ),
        centerTitle: true,
        actions: [
          TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditEventScreen(event: event)),
                );
                if (result == true) {
                  // Nếu edit thành công, thoát trang detail về lại trang list để reload
                  Navigator.pop(context, true);
                }
              },
            child: const Text("Edit", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- EVENT INFO CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD60A), // Màu vàng chuẩn iOS
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_filled, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          event.eventName ?? "Unnamed Event",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(color: Color(0xFF2C2C2E), thickness: 1),
                  ),

                  // Phần ngày tháng đã fix lỗi type Object
                  _buildDetailRow(
                      Icons.calendar_today_rounded,
                      formattedDate,
                      subTitle: _getDaysLeft(event.endDate as DateTime?)
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- ACTION BUTTONS ---
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildActionButton("Mark as finished", const Color(0xFF32D74B), () {
                    Provider.of<EventProvider>(context, listen: false).toggleStatus(event.id!);
                    Navigator.pop(context);
                  }),
                  const Divider(color: Color(0xFF2C2C2E), thickness: 1, height: 1),
                  _buildActionButton("Transaction book", const Color(0xFF32D74B), () {
                    // Điều hướng tới sổ giao dịch
                  }),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- DELETE BUTTON ---
            _buildActionButton("Delete", const Color(0xFFFF453A), () {
              _showDeleteConfirm(context);
            }, isSingle: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, {String? subTitle}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 22),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (subTitle != null && subTitle.isNotEmpty)
              Text(subTitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, Color textColor, VoidCallback onTap, {bool isSingle = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: isSingle
            ? BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16))
            : null,
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Delete Event", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this event?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.blue))
          ),
          TextButton(
            onPressed: () {
              Provider.of<EventProvider>(context, listen: false).delete(event.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Color(0xFFFF453A))),
          ),
        ],
      ),
    );
  }
}