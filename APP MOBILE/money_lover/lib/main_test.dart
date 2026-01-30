import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modules/category/providers/category_provider.dart';
import 'modules/category/screens/category_screen.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    // QUAN TRỌNG: MultiProvider phải nằm ở vị trí cao nhất có thể
    // để bao bọc toàn bộ MaterialApp hoặc ít nhất là bao bọc CategoryScreen
    return MultiProvider(
      providers: [
        // Đăng ký Provider tại đây
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),

        // CategoryScreen nằm trong child của MultiProvider -> OK!
        home: const CategoryScreen(),
      ),
    );
  }
}