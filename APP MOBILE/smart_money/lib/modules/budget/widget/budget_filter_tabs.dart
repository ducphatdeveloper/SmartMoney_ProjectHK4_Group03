import 'package:flutter/material.dart';

import '../enums/budget_type.dart';

class BudgetFilterTabs extends StatelessWidget {
  final BudgetType selected;
  final Function(BudgetType) onChanged;
  final List<BudgetType> availableTypes;

  const BudgetFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.availableTypes,
  });

  @override
  Widget build(BuildContext context) {
    if (availableTypes.isEmpty) return const SizedBox();

    return Row(
      children: availableTypes.map((type) {
        final isActive = selected == type;

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                type.label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}