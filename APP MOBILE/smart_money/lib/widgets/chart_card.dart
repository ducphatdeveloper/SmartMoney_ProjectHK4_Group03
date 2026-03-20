import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartCard extends StatefulWidget {
  const ChartCard({super.key});

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {

  int touchedIndex = -1;

  final List<ChartData> data = [
    ChartData("Ăn uống", 1200000, Colors.orange),
    ChartData("Xăng xe", 600000, Colors.blue),
    ChartData("Mua sắm", 900000, Colors.green),
    ChartData("Giải trí", 400000, Colors.purple),
    ChartData("Khác", 300000, Colors.grey),
  ];

  int get totalExpense =>
      data.fold(0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Chi tiêu theo danh mục",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 220,

              child: Stack(
                alignment: Alignment.center,

                children: [

                  PieChart(

                    PieChartData(

                      sectionsSpace: 3,
                      centerSpaceRadius: 70,

                      pieTouchData: PieTouchData(

                        touchCallback:
                            (event, response) {

                          setState(() {

                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {

                              touchedIndex = -1;
                              return;
                            }

                            touchedIndex =
                                response.touchedSection!.touchedSectionIndex;

                          });

                        },

                      ),

                      sections: List.generate(
                        data.length,
                            (i) {

                          final isTouched = i == touchedIndex;

                          final radius =
                          isTouched ? 65.0 : 55.0;

                          return PieChartSectionData(
                            color: data[i].color,
                            value: data[i].amount.toDouble(),
                            title: "",
                            radius: radius,
                          );

                        },
                      ),

                    ),

                  ),

                  /// CENTER TOTAL
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const Text(
                        "Tổng chi",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      Text(
                        "${totalExpense.toString()} đ",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  )

                ],
              ),
            ),

            const SizedBox(height: 20),

            /// LEGEND
            Column(
              children: data.map((e) {

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),

                  child: Row(

                    children: [

                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: e.color,
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Text(
                        e.name,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        "${e.amount} đ",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),
                );

              }).toList(),
            )

          ],
        ),
      ),
    );
  }
}

class ChartData {

  final String name;
  final int amount;
  final Color color;

  ChartData(this.name, this.amount, this.color);

}
