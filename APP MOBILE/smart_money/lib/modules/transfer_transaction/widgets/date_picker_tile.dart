import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const DatePickerTile({super.key, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text("Date"),
      trailing: Text(DateFormat('dd/MM/yyyy').format(date)),
      onTap: onTap,
    );
  }
}
