import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // For date formatting

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
    // Fetch notifications when the screen is initialized
    Future.microtask(() => context.read<NotificationProvider>().fetchNotifications());
  }

  // Function to show confirmation dialog for marking all as read
  void _showMarkAllReadConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Xác nhận"),
          content: const Text("Bạn có chắc chắn muốn đánh dấu tất cả thông báo là đã đọc?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Hủy"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text("Đánh dấu"),
              onPressed: () {
                context.read<NotificationProvider>().markAllAsRead();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              // Only show "Mark all as read" button if there are unread notifications
              if ((provider.unreadCount ?? 0) > 0) {
                return TextButton(
                  onPressed: () => _showMarkAllReadConfirmation(context),
                  child: const Text(
                    "Đánh dấu đã đọc tất cả",
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                );
              }
              return const SizedBox.shrink(); // Hide if no unread notifications
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          // Show loading indicator if fetching and no notifications yet
          if ((provider.isLoading == true) && (provider.notifications?.isEmpty ?? true)) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2));
          }

          // Show empty state if no notifications
          if (provider.notifications?.isEmpty ?? true) {
            return _buildEmptyState();
          }

          // Display notifications
          return RefreshIndicator(
            color: Colors.greenAccent,
            backgroundColor: const Color(0xFF1A1A1A),
            onRefresh: () => provider.fetchNotifications(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.notifications?.length ?? 0,
              itemBuilder: (context, index) {
                final item = provider.notifications![index]; // Use ! because we checked for isEmpty above
                return _buildNotificationItem(index, context, provider, item);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            "Bạn không có thông báo nào.",
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(int index, BuildContext context, NotificationProvider provider, NotificationResponse item) {
    IconData iconData;
    Color iconColor;

    // Determine icon and color based on notifyType
    switch (item.notifyType) {
      case 1: // Ví dụ: Giao dịch
        iconData = Icons.attach_money;
        iconColor = Colors.greenAccent;
        break;
      case 2: // Ví dụ: Nhắc nhở
        iconData = Icons.alarm;
        iconColor = Colors.orangeAccent;
        break;
      case 3: // Ví dụ: Cập nhật hệ thống
        iconData = Icons.system_update_alt;
        iconColor = Colors.blueAccent;
        break;
      default: // Icon mặc định
        iconData = Icons.info_outline;
        iconColor = Colors.grey;
        break;
    }

    return Dismissible(
      key: Key(item.id.toString()), // Sử dụng item.id làm key duy nhất
      direction: DismissDirection.endToStart, // Vuốt từ phải sang trái để xóa
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        // Tùy chọn: Hiển thị hộp thoại xác nhận trước khi xóa
        return await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("Xác nhận xóa"),
              content: const Text("Bạn có chắc chắn muốn xóa thông báo này?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Hủy"),
                ),
                TextButton(
                  onPressed: () async {
                    // Thực hiện xóa
                    await provider.deleteNotification(item.id);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Đã xóa thông báo"), duration: Duration(seconds: 1)),
                      );
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text("Xóa"),
                ),
              ],
            );
          },
        );
      },
      child: ListTile(
        onTap: () {
          // Đánh dấu đã đọc nếu chưa đọc
          if (item.notifyRead == false) {
            provider.markAsRead(item.id);
          }
          // Tùy chọn: Điều hướng đến màn hình liên quan dựa trên item.relatedId hoặc notifyType
          // if (item.relatedId != null) {
          //   context.push('/details/${item.relatedId}');
          // }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        tileColor: (item.notifyRead == true) ? Colors.transparent : Colors.greenAccent.withOpacity(0.03),
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
          item.title ?? "Thông báo mới", // Cung cấp giá trị mặc định cho title nullable
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 15,
            fontWeight: (item.notifyRead == true) ? FontWeight.normal : FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.content ?? "Không có nội dung", // Cung cấp giá trị mặc định cho content nullable
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                item.scheduledTime != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(item.scheduledTime!) // Định dạng ngày tháng
                    : "Vừa xong", // Giá trị mặc định cho scheduledTime nullable
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        trailing: (item.notifyRead == false) // Hiển thị chỉ báo chưa đọc
            ? const CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent)
            : null,
      ),
    );
  }
}