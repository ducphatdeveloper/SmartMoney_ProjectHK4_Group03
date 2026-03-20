import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSwitcher extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const DateSwitcher({
    super.key,
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final text = DateFormat('EEE, dd/MM', 'vi_VN').format(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
        Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}
