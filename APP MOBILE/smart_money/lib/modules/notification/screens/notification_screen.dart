import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
    Future.microtask(() => context.read<NotificationProvider>().fetchNotifications());
  }

  void _showMarkAllReadConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Confirm"),
          content: const Text("Are you sure you want to mark all notifications as read?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text("Mark as read"),
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
        title: const Text("Notifications"),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if ((provider.unreadCount ?? 0) > 0) {
                return TextButton(
                  onPressed: () => _showMarkAllReadConfirmation(context),
                  child: const Text(
                    "Mark all as read",
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if ((provider.isLoading == true) && (provider.notifications?.isEmpty ?? true)) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2));
          }

          if (provider.notifications?.isEmpty ?? true) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: Colors.greenAccent,
            backgroundColor: const Color(0xFF1A1A1A),
            onRefresh: () => provider.fetchNotifications(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.notifications?.length ?? 0,
              itemBuilder: (context, index) {
                final item = provider.notifications![index];
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
            "You have no notifications.",
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(int index, BuildContext context, NotificationProvider provider, NotificationResponse item) {
    IconData iconData;
    Color iconColor;

    switch (item.notifyType) {
      case 1:
        iconData = Icons.attach_money;
        iconColor = Colors.greenAccent;
        break;
      case 2:
        iconData = Icons.alarm;
        iconColor = Colors.orangeAccent;
        break;
      case 3:
        iconData = Icons.system_update_alt;
        iconColor = Colors.blueAccent;
        break;
      default:
        iconData = Icons.info_outline;
        iconColor = Colors.grey;
        break;
    }

    return Dismissible(
      key: Key(item.id.toString()),
      direction: DismissDirection.endToStart,
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
        return await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("Confirm Delete"),
              content: const Text("Are you sure you want to delete this notification?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    await provider.deleteNotification(item.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Notification deleted"), duration: Duration(seconds: 1)),
                      );
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text("Delete"),
                ),
              ],
            );
          },
        );
      },
      child: ListTile(
        onTap: () {
          if (item.notifyRead == false) {
            provider.markAsRead(item.id);
          }
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
          item.title ?? "New Notification",
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
                item.content ?? "No content",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                item.scheduledTime != null
                    ? DateFormat('MMM dd, yyyy HH:mm').format(item.scheduledTime!)
                    : "Just now",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        trailing: (item.notifyRead == false)
            ? const CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent)
            : null,
      ),
    );
  }
}