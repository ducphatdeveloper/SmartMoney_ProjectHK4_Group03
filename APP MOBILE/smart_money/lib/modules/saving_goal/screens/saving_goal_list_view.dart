import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/saving_goal_provider.dart';
import 'detail_saving_goal_screen.dart';
import '../../../core/constants/app_constants.dart';

class SavingGoalListView extends StatelessWidget {
  const SavingGoalListView({super.key});

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
    // Format số phân tách hàng nghìn
    final currencyFormat = NumberFormat("#,###", "vi_VN");
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        if (provider.goals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_graph_rounded, color: Colors.grey.withOpacity(0.3), size: 80),
                const SizedBox(height: 16),
                const Text("No active goals", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: provider.goals.length,
          itemBuilder: (context, index) {
            final goal = provider.goals[index];
            final progressValue = (goal.progressPercent ?? 0) / 100;
            final iconUrl = _fixUrl(goal.imageUrl);
            final bool isCompleted = goal.finished ?? (progressValue >= 1.0);
            //debugPrint("🟢 SAVING GOAL LINK: $iconUrl");

            // Lấy currency từ goal hoặc mặc định là VND
            final String currencyStr = goal.currencyCode ?? "VND";

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailSavingGoalScreen(goal: goal)),
                  );
                  if (result == true) provider.loadGoals();
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
                      // --- Phần Header ---
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGoalIcon(iconUrl, isCompleted),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.goalName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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

                      // --- Phần Thông tin chi tiết số dư (Đã thêm Currency) ---
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

                      // --- Phần Progress Bar ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isCompleted ? "Goal Completed 🎉" : "Progress",
                                  style: TextStyle(
                                      color: isCompleted ? Colors.greenAccent : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                                Text(
                                  "${(goal.progressPercent ?? 0).toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    color: isCompleted ? Colors.greenAccent : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildProgressBar(context, progressValue, isCompleted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalIcon(String iconUrl, bool isCompleted) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(2),
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
        child: ClipOval(
          child: iconUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: iconUrl,
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

  // Widget hiển thị thông tin số tiền - ĐÃ CẬP NHẬT THÊM THAM SỐ CURRENCY
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
              colors: isCompleted
                  ? [Colors.greenAccent, Colors.tealAccent]
                  : [Colors.orangeAccent, Colors.deepOrange],
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