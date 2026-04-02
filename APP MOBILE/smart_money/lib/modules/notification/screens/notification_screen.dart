import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_response.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Load thông báo khi vào màn hình
    Future.microtask(
      () => context.read<NotificationProvider>().fetchNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B), // Sâu hơn màu đen thuần
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        title: const Text(
          "Thông báo",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold, // Thay w800 bằng bold để an toàn cho font tiếng Việt
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => _showMarkAllReadConfirmation(context),
              child: const Text(
                "Đọc tất cả",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: provider.isLoading && provider.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2))
          : provider.notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Colors.greenAccent,
                  backgroundColor: const Color(0xFF1A1A1A),
                  onRefresh: () => provider.fetchNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.notifications.length,
                    itemBuilder: (context, index) {
                      final item = provider.notifications[index];
                      return _buildNotificationItem(context, provider, item);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 80, color: Colors.white24),
          ),
          const SizedBox(height: 24),
          const Text(
            "Hộp thư trống",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Chúng tôi sẽ thông báo khi có hoạt động mới",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationProvider provider, NotificationResponse item) {
    IconData iconData;
    Color iconColor;

    switch (item.notifyType) {
      case 1:
        iconData = Icons.add_chart_rounded;
        iconColor = Colors.greenAccent;
        break;
      case 2:
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.orangeAccent;
        break;
      case 3:
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.redAccent;
        break;
      default:
        iconData = Icons.notifications_rounded;
        iconColor = Colors.blueAccent;
    }

    return Dismissible(
      key: Key(item.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withOpacity(0.1),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (direction) {
        // provider.deleteNotification(item.id); // Giả định bạn sẽ thêm hàm này
      },
      child: ListTile(
        onTap: () {
          if (!item.notifyRead) provider.markAsRead(item.id);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        tileColor: item.notifyRead ? Colors.transparent : Colors.greenAccent.withOpacity(0.03),
        leading: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 15,
            fontWeight: item.notifyRead ? FontWeight.normal : FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                item.scheduledTime ?? "Vừa xong",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        trailing: !item.notifyRead
            ? const CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent)
            : null,
      ),
    );
  }

  void _showMarkAllReadConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
        content: const Text("Đánh dấu tất cả thông báo là đã đọc?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              context.read<NotificationProvider>().markAllAsRead();
              Navigator.pop(context);
            },
            child: const Text("Đồng ý", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }
}