import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';

/// Dialog chọn khoảng thời gian (Ngày, Tuần, Tháng, Quý, Năm, Tất cả, Tùy chỉnh)
class DateRangeModeDialog extends StatelessWidget {
  const DateRangeModeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final modes = [
      {'label': 'Day', 'value': 'DAILY'},
      {'label': 'Week', 'value': 'WEEKLY'},
      {'label': 'Month', 'value': 'MONTHLY'},
      {'label': 'Quarter', 'value': 'QUARTERLY'},
      {'label': 'Year', 'value': 'YEARLY'},
      {'label': 'All', 'value': 'ALL'},
      {'label': 'Custom', 'value': 'CUSTOM'},
    ];

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Time period',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((mode) {
          return Consumer<TransactionProvider>(
            builder: (context, provider, _) {
              final isSelected = !provider.isAllMode &&
                  !provider.isCustomMode &&
                  provider.dateRangeMode == mode['value'];

              return ListTile(
                title: Text(
                  mode['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(context);

                  if (mode['value'] == 'ALL') {
                    provider.loadAllTransactions();
                  } else if (mode['value'] == 'CUSTOM') {
                    showDialog(
                      context: context,
                      builder: (_) => const CustomDateRangeDialog(),
                    );
                  } else {
                    provider.changeDateRangeMode(mode['value']!);
                  }
                },
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

/// Dialog chọn ngày tùy chỉnh
class CustomDateRangeDialog extends StatefulWidget {
  const CustomDateRangeDialog({super.key});

  @override
  State<CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<CustomDateRangeDialog> {
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    startDate = DateTime.now().subtract(const Duration(days: 30));
    endDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Select time range',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Từ ngày
          ListTile(
            title: const Text('From', style: TextStyle(color: Colors.grey)),
            subtitle: Text(
              '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: const Icon(Icons.calendar_today, color: Colors.green),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2099),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: Colors.green),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => startDate = picked);
              }
            },
          ),
          const Divider(color: Colors.grey),
          // Đến ngày
          ListTile(
            title: const Text('To', style: TextStyle(color: Colors.grey)),
            subtitle: Text(
              '${endDate.day.toString().padLeft(2, '0')}/${endDate.month.toString().padLeft(2, '0')}/${endDate.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: const Icon(Icons.calendar_today, color: Colors.green),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: endDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2099),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: Colors.green),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => endDate = picked);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            Navigator.pop(context);
            final provider = context.read<TransactionProvider>();
            final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
            provider.loadCustomDateRange(startDate, end);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

