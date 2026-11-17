
import 'package:flutter/material.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);
const Color pageBackground = Color(0xFFF8F5F5);

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  int selectedTab = 0;
  int selectedCategory = 0;

  final List<Map<String, dynamic>> categories = [
    {'name': 'সব পণ্য', 'icon': Icons.grid_view_rounded},
    {'name': 'Fire Equipment', 'icon': Icons.fire_extinguisher},
    {'name': 'PPE', 'icon': Icons.health_and_safety_outlined},
    {'name': 'Fire Alarm', 'icon': Icons.notifications_active_outlined},
    {'name': 'Safety Sign', 'icon': Icons.signpost_outlined},
    {'name': 'Others', 'icon': Icons.category_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: deepMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marketplace',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Fire Safety Products & Services',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('কার্ট সুবিধা পরবর্তী ধাপে যুক্ত হবে।'),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'কার্ট',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            const SizedBox(height: 22),

            const Text(
              'ক্যাটাগরি',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deepMaroon,
              ),
            ),
            const SizedBox(height: 12),

            _buildCategories(),

            const SizedBox(height: 24),

            _buildTabSelector(),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedTab == 0
                      ? 'ফায়ার সেফটি পণ্য'
                      : 'ফায়ার সেফটি সার্ভিস',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon,
                  ),
                ),
                Text(
                  selectedTab == 0 ? 'Products' : 'Services',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildEmptyState(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [maroon, deepMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(height: 12),
          Text(
            'Fire Safety Marketplace',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'আপনার প্রয়োজনীয় ফায়ার সেফটি পণ্য ও সার্ভিস\nএক জায়গায় খুঁজে নিন।',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = selectedCategory == index;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              selectedCategory = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? maroon : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? maroon : Colors.grey.shade200,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category['icon'] as IconData,
                  size: 27,
                  color: selected ? Colors.white : maroon,
                ),
                const SizedBox(height: 8),
                Text(
                  category['name'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : deepMaroon,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _tabButton('পণ্য', 0, Icons.shopping_bag_outlined),
          _tabButton('সার্ভিস', 1, Icons.miscellaneous_services),
        ],
      ),
    );
  }

  Widget _tabButton(String title, int tab, IconData icon) {
    final selected = selectedTab == tab;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            selectedTab = tab;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? maroon : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : deepMaroon,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : deepMaroon,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            selectedTab == 0
                ? Icons.inventory_2_outlined
                : Icons.engineering_outlined,
            size: 48,
            color: maroon.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 12),
          Text(
            selectedTab == 0
                ? 'এখনো কোনো পণ্য প্রকাশ করা হয়নি'
                : 'এখনো কোনো সার্ভিস প্রকাশ করা হয়নি',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: deepMaroon,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'অ্যাডমিন প্যানেল থেকে পণ্য ও সার্ভিস যুক্ত হলে এখানে দেখা যাবে।',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
