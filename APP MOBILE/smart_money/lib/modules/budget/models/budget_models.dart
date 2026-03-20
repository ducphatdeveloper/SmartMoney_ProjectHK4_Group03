import 'package:flutter/material.dart';

class BudgetModel {
  final String id;
  final String name;
  final IconData icon;
  final double amount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final bool repeat;
  final String? note;

  BudgetModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.amount,
    this.startDate,
    this.endDate,
    this.categoryId,
    this.repeat = false,
    this.note,
  });

  BudgetModel copyWith({
    String? name,
    IconData? icon,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    bool? repeat,
    String? note,
  }) {
    return BudgetModel(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryId: categoryId ?? this.categoryId,
      repeat: repeat ?? this.repeat,
      note: note ?? this.note,
    );
  }
}
