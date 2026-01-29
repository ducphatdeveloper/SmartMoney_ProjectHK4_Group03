
import 'package:flutter/material.dart';
import '../widgets/summary_card.dart';
import '../widgets/chart_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("9,994,550,000 đ",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SummaryCard(),
            SizedBox(height: 16),
            ChartCard(),
          ],
        ),
      ),
    );
  }
}
