import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/account_screen.dart';

void main() {
  runApp(const MoneyLoverApp());
}

class MoneyLoverApp extends StatefulWidget {
  const MoneyLoverApp({super.key});

  @override
  State<MoneyLoverApp> createState() => _MoneyLoverAppState();
}

class _MoneyLoverAppState extends State<MoneyLoverApp> {
  int _index = 0;

  final screens = const [
    HomeScreen(),
    TransactionsScreen(),
    SizedBox(),
    BudgetScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: Scaffold(
        body: screens[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: Colors.black,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Tổng quan'),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'Sổ Giao dịch',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 36),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart),
              label: 'Ngân sách',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
