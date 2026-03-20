import 'package:flutter/material.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> groups = [
    {
      "name": "Ăn uống",
      "icon": Icons.local_bar,
      "color": Colors.blueGrey,
      "children": []
    },
    {
      "name": "Hoá đơn & Tiện ích",
      "icon": Icons.receipt,
      "color": Colors.grey,
      "children": [
        {"name": "Thuê nhà"},
        {"name": "Hoá đơn nước"},
        {"name": "Hoá đơn điện thoại"},
        {"name": "Hoá đơn điện"},
        {"name": "Hoá đơn gas"},
        {"name": "Hoá đơn TV"},
      ]
    }
  ];

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Nhóm"),
        backgroundColor: Colors.black,
        centerTitle: true,
        leading: const BackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "Khoản chi"),
                Tab(text: "Khoản thu"),
                Tab(text: "Vay/Nợ"),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ===== BUTTON NHÓM MỚI =====
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Nhóm mới",
                  style: TextStyle(color: Colors.green, fontSize: 16),
                )
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== LIST =====
          ...groups.map((g) => _groupItem(g)).toList(),

          const SizedBox(height: 16),

          // ===== FOOTER =====
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                Icon(Icons.remove_red_eye, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Hiển thị nhóm không hoạt động",
                  style: TextStyle(color: Colors.green),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ===== GROUP ITEM =====
  Widget _groupItem(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [

          // ===== PARENT =====
          ListTile(
            leading: CircleAvatar(
              backgroundColor: group["color"],
              child: Icon(group["icon"], color: Colors.white),
            ),
            title: Text(
              group["name"],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text("Yes", style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),

          // ===== CHILDREN =====
          if (group["children"].isNotEmpty)
            Column(
              children: List.generate(group["children"].length, (index) {
                final child = group["children"][index];
                return Row(
                  children: [
                    // line bên trái
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey,
                      ),
                    ),

                    Expanded(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.description, color: Colors.white),
                        ),
                        title: Text(
                          child["name"],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text("Yes",
                            style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.grey),
                      ),
                    ),
                  ],
                );
              }),
            )
        ],
      ),
    );
  }
}
