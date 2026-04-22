import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/wallet/providers/wallet_provider.dart';
import '../../../core/helpers/icon_helper.dart';
import '../models/saving_goal_response.dart';
import '../providers/saving_goal_provider.dart';
import 'edit_saving_goal_screen.dart';
import 'add_saving_goal_screen.dart';

class DetailSavingGoalScreen extends StatefulWidget {
  final SavingGoalResponse goal;
  const DetailSavingGoalScreen({super.key, required this.goal});

  @override
  State<DetailSavingGoalScreen> createState() => _DetailSavingGoalScreenState();
}

class _DetailSavingGoalScreenState extends State<DetailSavingGoalScreen> {
  final fmt = NumberFormat("#,###", "en_US");
  final dateFmt = DateFormat('dd MMM, yyyy');

  // Controllers
  late TextEditingController _simController;
  final TextEditingController _coffeeController = TextEditingController(text: "30,000");
  final TextEditingController _eatingOutController = TextEditingController(text: "150,000");
  final TextEditingController _partyController = TextEditingController(text: "500,000");
  final TextEditingController _otherController = TextEditingController(text: "50,000");
  final TextEditingController _emergencyValueController = TextEditingController(text: "20");

  double _simResultDays = 0;
  int _selectedFreqIndex = 0;
  final List<String> _frequencies = ["Day", "Week", "Month", "Year"];

  bool _cutCoffee = false;
  int _coffeeFreqIndex = 0;
  bool _cutEatingOut = false;
  int _eatingOutFreqIndex = 0;

  bool _cutParty = false;
  int _partyFreqIndex = 0;
  bool _cutOther = false;
  int _otherFreqIndex = 0;

  bool _isEmergencyHit = false;
  int _emergencyModeIndex = 0;
  bool _isOnTrack = false;

  @override
  void initState() {
    super.initState();
    _simController = TextEditingController(text: fmt.format(frequencyRequired));
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSimulation());
  }

  // --- LOGIC & CALCULATIONS ---
  int get daysRemaining => widget.goal.endDate.difference(DateTime.now()).inDays;

  double get dailyRequired => (widget.goal.remainingAmount > 0)
      ? (widget.goal.remainingAmount / (daysRemaining > 0 ? daysRemaining : 1)).ceilToDouble()
      : 0;

  double get frequencyRequired {
    double base = dailyRequired;
    if (_selectedFreqIndex == 0) return base;
    if (_selectedFreqIndex == 1) return base * 7;
    if (_selectedFreqIndex == 2) return base * 30;
    return base * 365;
  }

  bool get isOverdue => widget.goal.goalStatus == 4;
  bool get isCompleted => widget.goal.goalStatus == 2;
  bool get isCanceled => widget.goal.goalStatus == 3;
  bool get isFinished => widget.goal.finished ?? false;

  double _parseMoney(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  // HÀM MỚI: Xử lý quy đổi tiền tệ khi chuyển đổi Tab (Dùng chung cho Simulation và Sacrifice)
  void _handleFrequencyUpdate({
    required int oldIndex,
    required int newIndex,
    required TextEditingController controller,
    required Function(int) onIndexChanged,
  }) {
    double currentInput = _parseMoney(controller.text);

    // 1. Quy đổi về mức Daily gốc
    double dailyValue = 0;
    if (oldIndex == 0) dailyValue = currentInput;
    else if (oldIndex == 1) dailyValue = currentInput / 7;
    else if (oldIndex == 2) dailyValue = currentInput / 30;
    else dailyValue = currentInput / 365;

    // 2. Cập nhật index mới thông qua callback
    onIndexChanged(newIndex);

    // 3. Tính toán giá trị mới cho Tab vừa chọn
    double newVal = dailyValue;
    if (newIndex == 1) newVal = dailyValue * 7;
    else if (newIndex == 2) newVal = dailyValue * 30;
    else if (newIndex == 3) newVal = dailyValue * 365;

    // 4. Cập nhật UI
    setState(() {
      controller.text = fmt.format(newVal.ceil());
    });
    _runSimulation();
  }

  void _runSimulation({bool shouldUpdateController = false}) {
    double simulatedCurrentAmount = widget.goal.currentAmount;
    if (_isEmergencyHit) {
      double val = _parseMoney(_emergencyValueController.text);
      simulatedCurrentAmount = _emergencyModeIndex == 0
          ? simulatedCurrentAmount * (1 - (val / 100))
          : simulatedCurrentAmount - val;
      if (simulatedCurrentAmount < 0) simulatedCurrentAmount = 0;
    }

    double simulatedRemaining = widget.goal.targetAmount - simulatedCurrentAmount;
    double simulatedDailyRequired = (simulatedRemaining > 0)
        ? (simulatedRemaining / (daysRemaining > 0 ? daysRemaining : 1)).ceilToDouble()
        : 0;

    if (shouldUpdateController) {
      double baseToDisplay = simulatedDailyRequired;
      if (_selectedFreqIndex == 1) baseToDisplay *= 7;
      else if (_selectedFreqIndex == 2) baseToDisplay *= 30;
      else if (_selectedFreqIndex == 3) baseToDisplay *= 365;
      _simController.text = fmt.format(baseToDisplay);
    }

    final amountInput = _parseMoney(_simController.text);
    double dailyFromInput = 0;
    if (_selectedFreqIndex == 0) dailyFromInput = amountInput;
    else if (_selectedFreqIndex == 1) dailyFromInput = amountInput / 7;
    else if (_selectedFreqIndex == 2) dailyFromInput = amountInput / 30;
    else dailyFromInput = amountInput / 365;

    final extraSavings = _calculateExtra();
    final totalDaily = dailyFromInput + extraSavings;

    setState(() {
      _isOnTrack = (dailyFromInput.round() >= simulatedDailyRequired.round());
      if (totalDaily > 0) {
        _simResultDays = simulatedRemaining / totalDaily;
      } else {
        _simResultDays = 0;
      }
    });
  }

  double _calculateExtra() {
    double calc(bool act, TextEditingController c, int f) {
      if (!act) return 0;
      double p = _parseMoney(c.text);
      if (f == 0) return p;
      if (f == 1) return p / 7;
      if (f == 2) return p / 30;
      return p / 365;
    }
    return calc(_cutCoffee, _coffeeController, _coffeeFreqIndex)
        + calc(_cutEatingOut, _eatingOutController, _eatingOutFreqIndex)
        + calc(_cutParty, _partyController, _partyFreqIndex)
        + calc(_cutOther, _otherController, _otherFreqIndex);
  }

  // --- ACTION HANDLERS ---
  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor.withOpacity(0.2), foregroundColor: confirmColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleFinalize(BuildContext context, int goalId) async {
    final walletProvider = context.read<WalletProvider>();
    final selectedWalletId = await _showWalletSelectionDialog(context, "Select a wallet to transfer your savings to upon completion.");
    if (selectedWalletId == null || !mounted) return;
    final wallet = walletProvider.wallets.firstWhere((w) => w.id == selectedWalletId);

    final confirm = await _showConfirmDialog(
      title: "Finalize Goal",
      content: "Are you sure you want to finalize '${widget.goal.goalName}'? The total amount of ${fmt.format(widget.goal.currentAmount)} ${widget.goal.currencyCode} will be transferred to '${wallet.walletName}'.",
      confirmLabel: "Confirm",
      confirmColor: Colors.greenAccent,
    );

    if (!confirm || !mounted) return;
    final provider = context.read<SavingGoalProvider>();
    final success = await provider.completeGoal(context, goalId, walletId: selectedWalletId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goal finalized successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? "Failed to finalize goal"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleCancel(BuildContext context, int goalId) async {
    final walletProvider = context.read<WalletProvider>();
    final selectedWalletId = await _showWalletSelectionDialog(context, "Select a wallet to receive the withdrawn funds.");
    if (selectedWalletId == null || !mounted) return;
    final wallet = walletProvider.wallets.firstWhere((w) => w.id == selectedWalletId);

    final confirm = await _showConfirmDialog(
      title: "Cancel Goal",
      content: "This action will close the goal permanently. The amount of ${fmt.format(widget.goal.currentAmount)} ${widget.goal.currencyCode} will be returned to '${wallet.walletName}'.",
      confirmLabel: "Agree to Cancel",
      confirmColor: Colors.orangeAccent,
    );

    if (!confirm || !mounted) return;
    final provider = context.read<SavingGoalProvider>();
    final success = await provider.cancelGoal(context, goalId, walletId: selectedWalletId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goal cancelled successfully."), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? "Failed to cancel goal"), backgroundColor: Colors.red));
      }
    }
  }

  Future<int?> _showWalletSelectionDialog(BuildContext context, String title) async {
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.wallets.isEmpty) await walletProvider.loadAll();

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Select Wallet", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.maxFinite,
              height: 200,
              child: Consumer<WalletProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    itemCount: provider.wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = provider.wallets[index];
                      return ListTile(
                        leading: IconHelper.buildCircleAvatar(iconUrl: wallet.goalImageUrl, radius: 20),
                        title: Text(wallet.walletName, style: const TextStyle(color: Colors.white)),
                        onTap: () => Navigator.of(ctx).pop(wallet.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCompleted && isFinished) return _buildVictoryScreen();
    if (isOverdue) return _buildOverdueScreen();
    if (isCanceled) return _buildCanceledScreen();

    final goal = widget.goal;
    final currencyStr = goal.currencyCode ?? "VND";

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildMainGoalCard(goal, (goal.progressPercent ?? 0) / 100, currencyStr),
            const SizedBox(height: 30),
            _buildSectionTitle("Smart Simulation"),
            const SizedBox(height: 12),
            _buildSmartSimulator(currencyStr),
            const SizedBox(height: 30),
            _buildSectionTitle("Saving Strategy"),
            const SizedBox(height: 12),
            _buildStrategyGrid(currencyStr, goal),
            const SizedBox(height: 30),
            if (!isFinished) _buildActionButtons(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildSmartSimulator(String currency) {
    bool isFaster = _simResultDays.toInt() < daysRemaining;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Saving frequency:", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          _buildFrequencyToggle(_selectedFreqIndex, (idx) {
            _handleFrequencyUpdate(
              oldIndex: _selectedFreqIndex,
              newIndex: idx,
              controller: _simController,
              onIndexChanged: (v) => _selectedFreqIndex = v,
            );
          }),
          const SizedBox(height: 16),
          _buildCustomTextField(_simController, currency, (v) {
            _runSimulation(shouldUpdateController: false);
          }),
          const Divider(color: Colors.white10, height: 32),
          const Text("Reduce spending:", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          _buildFlexibleSacrifice(
            icon: Icons.coffee,
            label: "Coffee cost",
            controller: _coffeeController,
            isActive: _cutCoffee,
            freqIdx: _coffeeFreqIndex,
            onToggle: (v) { setState(() => _cutCoffee = v!); _runSimulation(); },
            onFreqChange: (idx) {
              _handleFrequencyUpdate(
                oldIndex: _coffeeFreqIndex,
                newIndex: idx,
                controller: _coffeeController,
                onIndexChanged: (v) => _coffeeFreqIndex = v,
              );
            },
          ),
          _buildFlexibleSacrifice(
            icon: Icons.restaurant,
            label: "Eating out",
            controller: _eatingOutController,
            isActive: _cutEatingOut,
            freqIdx: _eatingOutFreqIndex,
            onToggle: (v) { setState(() => _cutEatingOut = v!); _runSimulation(); },
            onFreqChange: (idx) {
              _handleFrequencyUpdate(
                oldIndex: _eatingOutFreqIndex,
                newIndex: idx,
                controller: _eatingOutController,
                onIndexChanged: (v) => _eatingOutFreqIndex = v,
              );
            },
          ),
          _buildFlexibleSacrifice(
            icon: Icons.celebration,
            label: "Party/Events",
            controller: _partyController,
            isActive: _cutParty,
            freqIdx: _partyFreqIndex,
            onToggle: (v) { setState(() => _cutParty = v!); _runSimulation(); },
            onFreqChange: (idx) {
              _handleFrequencyUpdate(
                oldIndex: _partyFreqIndex,
                newIndex: idx,
                controller: _partyController,
                onIndexChanged: (v) => _partyFreqIndex = v,
              );
            },
          ),
          _buildFlexibleSacrifice(
            icon: Icons.more_horiz,
            label: "Other expenses",
            controller: _otherController,
            isActive: _cutOther,
            freqIdx: _otherFreqIndex,
            onToggle: (v) { setState(() => _cutOther = v!); _runSimulation(); },
            onFreqChange: (idx) {
              _handleFrequencyUpdate(
                oldIndex: _otherFreqIndex,
                newIndex: idx,
                controller: _otherController,
                onIndexChanged: (v) => _otherFreqIndex = v,
              );
            },
          ),
          const Divider(color: Colors.white10, height: 32),
          _buildEmergencySwitch(),
          const Divider(color: Colors.white10, height: 32),
          _buildResultRow(isFaster),
        ],
      ),
    );
  }

  Widget _buildStrategyGrid(String currency, SavingGoalResponse goal) {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.1,
      children: [
        _buildStatCard("Daily Needed", dailyRequired, currency, Icons.bolt, Colors.greenAccent),
        _buildStatCard("Monthly Min", (dailyRequired * 30), currency, Icons.calendar_month, Colors.blueAccent),
        _buildStatCard("Days Left", daysRemaining.toDouble(), "Days", Icons.timer, Colors.orangeAccent, isCurrency: false),
        _buildStatCard("Total Remaining", goal.remainingAmount, currency, Icons.flag_rounded, Colors.redAccent),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      title: const Text("Analytics Dashboard", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  Widget _buildMainGoalCard(SavingGoalResponse goal, double progress, String currency) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(30)),
      child: Column(children: [
        Row(children: [
          IconHelper.buildCircleAvatar(iconUrl: goal.imageUrl, radius: 28),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal.goalName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Target: ${fmt.format(goal.targetAmount)} $currency", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          if (!isFinished) IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditSavingGoalScreen(goal: goal))),
              icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18)
          ),
        ]),
        const SizedBox(height: 20),
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 120, height: 120, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), strokeWidth: 10, backgroundColor: Colors.white.withOpacity(0.05), color: progress >= 1.0 ? Colors.greenAccent : Colors.orangeAccent)),
          Text("${(progress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 20),
        Text("Deadline: ${dateFmt.format(goal.endDate)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  Widget _buildEmergencySwitch() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Unexpected expense", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
          Text("Simulate a withdrawal", style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        Switch(value: _isEmergencyHit, onChanged: (v) {
          setState(() => _isEmergencyHit = v);
          _runSimulation(shouldUpdateController: true);
        }, activeColor: Colors.redAccent)
      ]),
      if (_isEmergencyHit) Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(children: [
          _buildSmallToggle(0, "%", _emergencyModeIndex, (idx) { setState(() => _emergencyModeIndex = idx); _runSimulation(shouldUpdateController: true); }),
          const SizedBox(width: 8),
          _buildSmallToggle(1, "Cash", _emergencyModeIndex, (idx) { setState(() => _emergencyModeIndex = idx); _runSimulation(shouldUpdateController: true); }),
          const SizedBox(width: 12),
          Expanded(child: _buildCustomTextField(_emergencyValueController, _emergencyModeIndex == 0 ? "%" : "VND", (v) => _runSimulation(shouldUpdateController: true), small: true)),
        ]),
      )
    ]);
  }

  Widget _buildSmallToggle(int index, String label, int selectedIdx, Function(int) onTap) {
    bool isSel = index == selectedIdx;
    return GestureDetector(onTap: () => onTap(index), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isSel ? Colors.redAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSel ? Colors.redAccent : Colors.white10)), child: Text(label, style: TextStyle(color: isSel ? Colors.redAccent : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold))));
  }

  Widget _buildFrequencyToggle(int selectedIdx, Function(int) onTap) {
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(14)), child: Row(children: List.generate(_frequencies.length, (index) => Expanded(child: GestureDetector(onTap: () => onTap(index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: selectedIdx == index ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(_frequencies[index], style: TextStyle(color: selectedIdx == index ? Colors.white : Colors.white38, fontSize: 12, fontWeight: selectedIdx == index ? FontWeight.bold : FontWeight.normal)))))))));
  }

  Widget _buildCustomTextField(TextEditingController controller, String suffix, Function(String) onChanged, {bool small = false}) {
    return SizedBox(height: small ? 40 : null, child: TextField(controller: controller, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CurrencyInputFormatter()], onChanged: onChanged, style: TextStyle(color: Colors.white, fontSize: small ? 14 : 20, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: Icon(small ? Icons.edit : Icons.savings_outlined, color: Colors.blueAccent, size: small ? 16 : 22), suffixText: suffix, suffixStyle: const TextStyle(color: Colors.white38, fontSize: 10), filled: true, fillColor: Colors.black.withOpacity(0.3), contentPadding: small ? const EdgeInsets.symmetric(horizontal: 12) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))));
  }

  Widget _buildFlexibleSacrifice({required IconData icon, required String label, required TextEditingController controller, required bool isActive, required int freqIdx, required Function(bool?) onToggle, required Function(int) onFreqChange}) {
    return Column(children: [CheckboxListTile(value: isActive, onChanged: onToggle, title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)), secondary: Icon(icon, color: Colors.orangeAccent, size: 20), contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact, activeColor: Colors.blueAccent), if (isActive) Padding(padding: const EdgeInsets.only(left: 45, bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildCustomTextField(controller, "VND", (v) => _runSimulation(), small: true), const SizedBox(height: 8), Row(children: List.generate(_frequencies.length, (index) => GestureDetector(onTap: () => onFreqChange(index), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: freqIdx == index ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: freqIdx == index ? Colors.blueAccent : Colors.white10)), child: Text(_frequencies[index], style: TextStyle(color: freqIdx == index ? Colors.blueAccent : Colors.white38, fontSize: 10))))))]))]);
  }

  Widget _buildResultRow(bool isFaster) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_isEmergencyHit) {
      statusColor = Colors.redAccent;
      statusText = "🚨 Emergency Mode: Plan adjusted to maintain deadline!";
      statusIcon = Icons.warning_amber_rounded;
    } else if (_isOnTrack) {
      statusColor = Colors.blueAccent;
      statusText = "✓ On track with your plan";
      statusIcon = Icons.check_circle_outline;
    } else if (isFaster) {
      statusColor = Colors.greenAccent;
      statusText = "🚀 Reach goal BEFORE deadline";
      statusIcon = Icons.speed;
    } else {
      statusColor = Colors.orangeAccent;
      statusText = "⚠ Slower than deadline";
      statusIcon = Icons.hourglass_empty;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Estimated finish in:", style: TextStyle(color: Colors.grey, fontSize: 14)),
        Text("${_simResultDays.ceil()} Days", style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold))
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      )
    ]);
  }

  Widget _buildStatCard(String title, double value, String unit, IconData icon, Color color, {bool isCurrency = true}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 24), const SizedBox(height: 8), Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)), FittedBox(child: Text(isCurrency ? "${fmt.format(value)} $unit" : "${value.toInt()} $unit", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))]));
  }

  Widget _buildActionButtons() {
    return Column(children: [
      _buildActionButton("Finalize Goal", Icons.verified_user_rounded, Colors.greenAccent, () => _handleFinalize(context, widget.goal.id)),
      const SizedBox(height: 12),
      _buildActionButton("Cancel Goal", Icons.assignment_return_rounded, Colors.orangeAccent, () => _handleCancel(context, widget.goal.id)),
    ]);
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label), style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.1), foregroundColor: color, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));
  }

  Widget _buildSectionTitle(String title) => Text(title.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5));

  // --- SCREENS ---
  Widget _buildOverdueScreen() {
    return Scaffold(backgroundColor: Colors.black, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, color: Colors.redAccent, size: 100), const SizedBox(height: 24), const Text("GOAL EXPIRED", style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)), const SizedBox(height: 10), Text("Overdue by ${daysRemaining.abs()} days", style: const TextStyle(color: Colors.white70, fontSize: 16)), const Padding(padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20), child: Text("You didn't reach the goal in time. Don't give up, adjust your deadline!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.italic))), const SizedBox(height: 20), _buildActionButton("EXTEND DEADLINE", Icons.history, Colors.redAccent, () { Navigator.push(context, MaterialPageRoute(builder: (_) => EditSavingGoalScreen(goal: widget.goal))); }), const SizedBox(height: 12), _buildActionButton("CLOSE", Icons.close, Colors.white24, () => Navigator.pop(context))])));
  }

  Widget _buildVictoryScreen() {
    return Scaffold(backgroundColor: const Color(0xFF0A0A0A), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 120), const SizedBox(height: 20), const Text("EXCELLENT!", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)), const Text("You have successfully reached your goal.", style: TextStyle(color: Colors.greenAccent, fontSize: 16)), const SizedBox(height: 40), Text(widget.goal.goalName, style: const TextStyle(color: Colors.white70)), Text("${fmt.format(widget.goal.targetAmount)} ${widget.goal.currencyCode}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 40), _buildActionButton("NEW GOAL", Icons.add_task, Colors.blueAccent, () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSavingGoalScreen())); }), const SizedBox(height: 12), _buildActionButton("CLOSE", Icons.check_circle, Colors.greenAccent, () => Navigator.pop(context))])));
  }

  Widget _buildCanceledScreen() {
    return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: _buildAppBar(),
        body: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.block, color: Colors.white24, size: 80),
              const SizedBox(height: 16),
              const Text("Goal Terminated", style: TextStyle(color: Colors.white, fontSize: 20)),
              const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("This goal has been closed. Ready to start a new saving journey?",
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white38))),
              const SizedBox(height: 20),
              _buildActionButton("CREATE NEW GOAL", Icons.add_circle_outline, Colors.blueAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSavingGoalScreen()));
              }),
              const SizedBox(height: 12),
              _buildActionButton("GO BACK", Icons.arrow_back, Colors.white10, () => Navigator.pop(context))
            ])));
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');
    final formatter = NumberFormat("#,###", "en_US");
    String formattedText = formatter.format(int.parse(cleanText));
    return newValue.copyWith(text: formattedText, selection: TextSelection.collapsed(offset: formattedText.length));
  }
}