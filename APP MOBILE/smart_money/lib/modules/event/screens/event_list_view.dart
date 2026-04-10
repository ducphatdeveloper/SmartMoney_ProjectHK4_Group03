import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/event_provider.dart';
import '../models/event_response.dart';
import 'event_detail_screen.dart';

class EventListView extends StatefulWidget {
  final String? accessToken;
  const EventListView({super.key, this.accessToken});

  @override
  State<EventListView> createState() => _EventListViewState();
}

class _EventListViewState extends State<EventListView> {

  @override
  void initState() {
    super.initState();
    // Tự động tải dữ liệu ngay khi vào trang
    _handleRefresh();
  }

  /// Hàm xử lý lấy dữ liệu mới nhất
  Future<void> _handleRefresh() async {
    // Đảm bảo widget đã mount trước khi gọi Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // forceRefresh: true để server trả về dữ liệu mới nhất, không dùng cache
        // false ở tham số đầu tiên thường là mặc định lấy "Active Events"
        context.read<EventProvider>().loadEvents(false, forceRefresh: true);
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, provider, child) {
        // Hiển thị loading khi đang tải và danh sách đang trống
        if (provider.isLoading && provider.events.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        // Trường hợp không có dữ liệu
        if (provider.events.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.greenAccent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_note_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      const Text("No events found", style: TextStyle(color: Colors.white30)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Danh sách hiển thị
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Colors.greenAccent,
          backgroundColor: const Color(0xFF1C1C1E),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: provider.events.length,
            itemBuilder: (context, index) {
              final e = provider.events[index];
              final iconUrl = _fixUrl(e.eventIconUrl);
              return _buildItem(context, e, iconUrl);
            },
          ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, EventResponse e, String iconUrl) {
    final bool isFinished = e.finished ?? false;
    final now = DateTime.now();
    double timeProgress = 0;

    if (e.beginDate != null) {
      final totalDays = e.endDate.difference(e.beginDate!).inDays;
      final elapsedDays = now.difference(e.beginDate!).inDays;
      if (totalDays > 0) timeProgress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: () async {
            // Đợi khi quay lại từ màn hình chi tiết
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
            );
            // Luôn làm mới dữ liệu khi quay lại để cập nhật số dư/trạng thái
            _handleRefresh();
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _buildEventIcon(iconUrl, isFinished),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.eventName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white.withOpacity(0.4)),
                              const SizedBox(width: 4),
                              Text(
                                "${e.beginDate != null ? DateFormat('dd MMM').format(e.beginDate!) : '??'} - ${DateFormat('dd MMM yyyy').format(e.endDate)}",
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(isFinished),
                  ],
                ),
              ),
              _buildFinanceRow(e),
              _buildProgressBar(e, timeProgress),
            ],
          ),
        ),
      ),
    );
  }

  // ... Các hàm _buildEventIcon, _buildFinanceRow, _buildProgressBar giữ nguyên như cũ ...
  // (Đảm bảo sử dụng widget.accessToken trong CachedNetworkImage)

  Widget _buildEventIcon(String url, bool isFinished) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isFinished
              ? [Colors.blueAccent, Colors.tealAccent]
              : [const Color(0xFF50E3C2), const Color(0xFF2196F3)],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle),
        child: ClipOval(
          child: url.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: url,
            httpHeaders: widget.accessToken != null ? {"Authorization": "Bearer ${widget.accessToken}"} : null,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1))),
            errorWidget: (context, url, error) => const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 26),
          )
              : const Icon(Icons.event_available, color: Colors.greenAccent, size: 26),
        ),
      ),
    );
  }

  Widget _buildFinanceRow(EventResponse e) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildFinanceItem("Income", e.totalIncome, Colors.greenAccent, e.currencyCode),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildFinanceItem("Expense", e.totalExpense, Colors.redAccent, e.currencyCode),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildFinanceItem("Balance", e.netAmount, Colors.blueAccent, e.currencyCode),
        ],
      ),
    );
  }

  Widget _buildFinanceItem(String label, double amount, Color color, String? currencyCode) {
    final fmt = NumberFormat.compact(locale: 'vi_VN');
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "${fmt.format(amount)} ${currencyCode ?? 'VND'}",
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(EventResponse e, double timeProgress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Event Progress", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w600)),
              Text("${(timeProgress * 100).toInt()}%", style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: timeProgress,
              backgroundColor: Colors.white.withOpacity(0.05),
              color: (e.finished ?? false) ? Colors.blueAccent : Colors.greenAccent,
              minHeight: 4,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool finished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: finished ? Colors.blueAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        finished ? "FINISHED" : "ACTIVE",
        style: TextStyle(color: finished ? Colors.blueAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}