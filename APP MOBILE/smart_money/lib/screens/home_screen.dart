import 'package:flutter/material.dart';
import 'package:smart_money/widgets/chart_card.dart';
import 'package:smart_money/widgets/summary_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  bool isBalanceHidden = false;

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  const Text(
                    "Money Lover",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Row(
                    children: [

                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {},
                      ),

                      Stack(
                        children: [

                          IconButton(
                            icon: const Icon(Icons.notifications_none),
                            onPressed: () {},
                          ),

                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                "2",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          )

                        ],
                      )

                    ],
                  )

                ],
              ),

              const SizedBox(height: 20),

              /// WALLET CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff4facfe),
                      Color(0xff00f2fe)
                    ],
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Ví chính",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [

                        Text(
                          isBalanceHidden
                              ? "••••••••"
                              : "9,994,550,000 đ",

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(width: 10),

                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isBalanceHidden = !isBalanceHidden;
                            });
                          },
                          child: Icon(
                            isBalanceHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                        )

                      ],
                    )

                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// MONTH FILTER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [

                  Text(
                    "Tháng 3 / 2026",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Icon(Icons.keyboard_arrow_down)

                ],
              ),

              const SizedBox(height: 20),

              /// SUMMARY
              const SummaryCard(),

              const SizedBox(height: 24),

              /// CHART
              const ChartCard(),

              const SizedBox(height: 30),

              /// RECENT TRANSACTIONS
              const Text(
                "Giao dịch gần đây",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [

                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.fastfood, color: Colors.white),
                    ),
                    title: Text("Ăn uống"),
                    subtitle: Text("Hôm nay"),
                    trailing: Text(
                      "-50,000 đ",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.directions_car, color: Colors.white),
                    ),
                    title: Text("Xăng xe"),
                    subtitle: Text("Hôm qua"),
                    trailing: Text(
                      "-40,000 đ",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.shopping_bag, color: Colors.white),
                    ),
                    title: Text("Mua sắm"),
                    subtitle: Text("20/03"),
                    trailing: Text(
                      "-200,000 đ",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                ],
              )

            ],
          ),
        ),
      ),
    );
  }
}