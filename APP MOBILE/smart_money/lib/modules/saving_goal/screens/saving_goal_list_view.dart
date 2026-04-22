import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/saving_goal_provider.dart';
import 'detail_saving_goal_screen.dart';
import '../../../core/constants/app_constants.dart';

class SavingGoalListView extends StatefulWidget {
  final String? accessToken;
  final bool isFinished;

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
    _handleRefresh();
  }

  @override
  void didUpdateWidget(covariant SavingGoalListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFinished != widget.isFinished) {
      _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SavingGoalProvider>().loadGoals(
          widget.isFinished,
          forceRefresh: true,
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

  Color _getProgressColor(double percent, int goalStatus) {
    if (goalStatus == 4) return Colors.redAccent;
    if (percent >= 100) return Colors.greenAccent;
    if (percent >= 75) return Colors.tealAccent;
    if (percent >= 50) return Colors.cyanAccent;
    if (percent >= 25) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final compactFormat = NumberFormat.compact(locale: "en_US");
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Consumer<SavingGoalProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        final displayList = provider.goals;

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
                        size: 80,
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
              final progressPercent = goal.progressPercent ?? 0.0;
              final progressValue = progressPercent / 100;

              final int goalStatus = goal.goalStatus ?? 1;
              final bool isOverdue = goalStatus == 4;
              final bool isFullyFunded = progressPercent >= 100;
              final bool isGoalFinished = goal.finished ?? false;
              final bool isCompleted = goalStatus == 2; // Da chot so
              final bool isCancelled = goalStatus == 3;

              // Logic: An progress bar neu da chot so (Finalized/Completed) hoac bi Huy
              final bool isFinalizedMode = isCompleted || isGoalFinished;
              final bool hideProgress = isFinalizedMode || isCancelled;

              final iconUrl = _fixUrl(goal.imageUrl);
              final String currencyStr = goal.currencyCode ?? "VND";

              // Lay mau sac chu dao cho text trang thai
              Color statusTextColor = _getProgressColor(progressPercent, goalStatus);
              if (isFinalizedMode) statusTextColor = Colors.greenAccent;
              if (isCancelled) statusTextColor = Colors.grey.shade500;

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailSavingGoalScreen(goal: goal)),
                    );
                    if (result == true && mounted) _handleRefresh();
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
                          isOverdue
                              ? const Color(0xFF3D1A1A).withOpacity(0.8)
                              : const Color(0xFF1C1C1E).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isOverdue
                            ? Colors.redAccent.withOpacity(0.3)
                            : isFinalizedMode || isFullyFunded
                            ? Colors.greenAccent.withOpacity(0.2)
                            : isCancelled
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGoalIcon(iconUrl, isFinalizedMode || isFullyFunded, isCancelled, isOverdue),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildAmountInfo("CURRENT", goal.currentAmount, compactFormat, currencyStr, Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildAmountInfo(
                                  "REMAINING",
                                  goal.remainingAmount,
                                  compactFormat,
                                  currencyStr,
                                  isOverdue ? Colors.redAccent : (goal.remainingAmount <= 0 || isFinalizedMode ? Colors.greenAccent : Colors.orangeAccent),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildAmountInfo("TARGET", goal.targetAmount, compactFormat, currencyStr, Colors.grey.shade400),
                              ),
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
                                    isCancelled ? "Goal Cancelled" :
                                    isFinalizedMode ? "Finalized 🎉" :
                                    isFullyFunded ? "Goal Completed 🎉" :
                                    _getProgressLabel(goalStatus, isGoalFinished),
                                    style: TextStyle(
                                      color: statusTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!hideProgress)
                                    Text(
                                      "${progressPercent.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        color: statusTextColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                              if (!hideProgress) ...[
                                const SizedBox(height: 8),
                                _buildProgressBar(context, progressValue, isFinalizedMode || isFullyFunded, statusTextColor),
                              ],
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

  // --- HELPERS ---

  String _getProgressLabel(int goalStatus, bool isFinished) {
    switch (goalStatus) {
      case 2: return "Finalized 🎉";
      case 3: return "Cancelled";
      case 4: return "Overdue ⚠️";
      default: return "Progress";
    }
  }

  Widget _buildGoalIcon(String iconUrl, bool isDone, bool isCancelled, bool isOverdue) {
    return Container(
      width: 52, height: 52, padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isOverdue ? [Colors.redAccent, Colors.red.shade900] :
          isDone ? [Colors.greenAccent, Colors.blueAccent] :
          isCancelled ? [Colors.grey.shade600, Colors.grey.shade400] :
          [Colors.orangeAccent, Colors.redAccent],
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
            errorWidget: (_, __, ___) => Icon(Icons.savings_rounded, color: isOverdue ? Colors.redAccent : Colors.orangeAccent),
          )
              : Icon(Icons.savings_rounded, color: isOverdue ? Colors.redAccent : Colors.orangeAccent, size: 24),
        ),
      ),
    );
  }

  Widget _buildStatusBadges(dynamic goal) {
    return Row(
      children: [
        if (goal.notified == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.notifications_active_outlined, size: 16, color: Colors.blueAccent)),
        if (goal.reportable == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.pie_chart_outline_rounded, size: 16, color: Colors.purpleAccent)),
      ],
    );
  }

  Widget _buildAmountInfo(String label, double amount, NumberFormat format, String currency, Color amountColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text("${format.format(amount)} $currency", style: TextStyle(color: amountColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, bool isCompleted, Color dynamicColor) {
    return Stack(
      children: [
        Container(height: 8, decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20))),
        LayoutBuilder(
          builder: (context, constraints) {
            final double progressWidth = (progress > 1 ? 1 : (progress < 0 ? 0 : progress)) * constraints.maxWidth;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 800), width: progressWidth, height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: isCompleted ? [Colors.greenAccent, Colors.tealAccent] : [dynamicColor.withOpacity(0.7), dynamicColor]),
                boxShadow: [BoxShadow(color: dynamicColor.withOpacity(0.3), blurRadius: 6)],
              ),
            );
          },
        ),
      ],
    );
  }
}