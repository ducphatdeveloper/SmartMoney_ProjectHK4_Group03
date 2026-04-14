import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/saving_goal_provider.dart';
import 'detail_saving_goal_screen.dart';
import '../../../core/constants/app_constants.dart';

class SavingGoalListView extends StatefulWidget {
  final String? accessToken;
  final bool isFinished; // false: Active, true: Finished

  const SavingGoalListView({
    super.key,
    this.accessToken,
    required this.isFinished,
  });

  @override
  State<SavingGoalListView> createState() => _SavingGoalListViewState();
}

class _SavingGoalListViewState extends State<SavingGoalListView> {
  @override
  void initState() {
    super.initState();
    // Khởi tạo dữ liệu đúng tab khi vào màn hình
    _handleRefresh();
  }

  @override
  void didUpdateWidget(covariant SavingGoalListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu tab thay đổi (vuốt qua lại), tự động load lại dữ liệu cho tab mới
    if (oldWidget.isFinished != widget.isFinished) {
      _handleRefresh();
    }
  }

  /// Hàm xử lý tải/làm mới dữ liệu từ Server
  Future<void> _handleRefresh() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SavingGoalProvider>().loadGoals(
            widget.isFinished,
            forceRefresh: true
        );
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
    final currencyFormat = NumberFormat("#,###", "vi_VN");
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        // Hiển thị loading khi list trống và đang tải
        if (provider.isLoading && provider.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        // Dữ liệu hiển thị (Đã được Provider filter sẵn từ API)
        final displayList = provider.goals;

        // Trường hợp danh sách trống
        if (displayList.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.greenAccent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    children: [
                      Icon(
                          widget.isFinished ? Icons.assignment_turned_in_rounded : Icons.auto_graph_rounded,
                          color: Colors.grey.withOpacity(0.3),
                          size: 80
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isFinished ? "No goals completed yet" : "No active goals found",
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Colors.greenAccent,
          backgroundColor: const Color(0xFF1C1C1E),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final goal = displayList[index];
              final progressValue = (goal.progressPercent ?? 0) / 100;
              final iconUrl = _fixUrl(goal.imageUrl);
              final bool isGoalFinished = goal.finished ?? false;
              final int goalStatus = goal.goalStatus ?? 1; // 1=ACTIVE, 2=COMPLETED, 3=CANCELLED, 4=OVERDUE
              final bool isCompletedStyle = goalStatus == 2; // xanh cho COMPLETED
              final bool isCancelledStyle = goalStatus == 3; // xam cho CANCELLED
              final String currencyStr = goal.currencyCode ?? "VND";

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailSavingGoalScreen(goal: goal)),
                    );
                    // Nếu quay lại từ chi tiết và có thay đổi trạng thái/xóa
                    if (result == true && mounted) {
                      _handleRefresh();
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
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
                          color: isCompletedStyle
                              ? Colors.greenAccent.withOpacity(0.2)
                              : isCancelledStyle ? Colors.grey.withOpacity(0.2) : Colors.white.withOpacity(0.05),
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
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGoalIcon(iconUrl, isCompletedStyle, isCancelledStyle),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.goalName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          "End: ${dateFormat.format(goal.endDate)}",
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadges(goal),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildAmountInfo("CURRENT", goal.currentAmount, currencyFormat, currencyStr, Colors.white),
                              _buildAmountInfo("REMAINING", goal.remainingAmount, currencyFormat, currencyStr,
                                  goal.remainingAmount <= 0 ? Colors.greenAccent : Colors.orangeAccent),
                              _buildAmountInfo("TARGET", goal.targetAmount, currencyFormat, currencyStr, Colors.grey.shade400),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getProgressLabel(goalStatus, isGoalFinished),
                                    style: TextStyle(
                                        color: isCompletedStyle ? Colors.greenAccent : isCancelledStyle ? Colors.grey.shade500 : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "${(goal.progressPercent ?? 0).toStringAsFixed(1)}%",
                                    style: TextStyle(
                                      color: isCompletedStyle ? Colors.greenAccent : Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildProgressBar(context, progressValue, isCompletedStyle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- WIDGETS CON ---

  // Lay nhan progress dua tren goalStatus tu backend
  // goalStatus: 1=ACTIVE, 2=COMPLETED, 3=CANCELLED, 4=OVERDUE
  String _getProgressLabel(int goalStatus, bool isFinished) {
    switch (goalStatus) {
      case 2: return isFinished ? "Finalized 🎉" : "Goal Completed 🎉";
      case 3: return "Goal Cancelled";
      case 4: return "Overdue";
      default: return "Progress";
    }
  }

  Widget _buildGoalIcon(String iconUrl, bool isCompleted, bool isCancelled) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isCompleted ? [Colors.greenAccent, Colors.blueAccent] : isCancelled ? [Colors.grey.shade600, Colors.grey.shade400] : [Colors.orangeAccent, Colors.redAccent],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF1C1C1E), shape: BoxShape.circle),
        child: ClipOval(
          child: iconUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: iconUrl,
            httpHeaders: widget.accessToken != null ? {"Authorization": "Bearer ${widget.accessToken}"} : null,
            fit: BoxFit.scaleDown,
            errorWidget: (_, __, ___) => const Icon(Icons.savings_rounded, color: Colors.orangeAccent),
          )
              : const Icon(Icons.savings_rounded, color: Colors.orangeAccent, size: 24),
        ),
      ),
    );
  }

  Widget _buildStatusBadges(dynamic goal) {
    return Row(
      children: [
        if (goal.notified == true)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.notifications_active_outlined, size: 16, color: Colors.blueAccent),
          ),
        if (goal.reportable == true)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.pie_chart_outline_rounded, size: 16, color: Colors.purpleAccent),
          ),
      ],
    );
  }

  Widget _buildAmountInfo(String label, double amount, NumberFormat format, String currency, Color amountColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              format.format(amount),
              style: TextStyle(color: amountColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            Text(
              currency,
              style: TextStyle(color: amountColor.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, bool isCompleted) {
    return Stack(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          width: (MediaQuery.of(context).size.width - 72) * (progress > 1 ? 1 : (progress < 0 ? 0 : progress)),
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isCompleted ? [Colors.greenAccent, Colors.tealAccent] : [Colors.orangeAccent, Colors.deepOrange],
            ),
            boxShadow: [
              BoxShadow(
                color: (isCompleted ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.3),
                blurRadius: 6,
              )
            ],
          ),
        ),
      ],
    );
  }
}