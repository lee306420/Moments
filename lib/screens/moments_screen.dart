import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/moment_provider.dart';
import '../widgets/moment_card.dart';
import 'new_moment_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';

class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadMoments());
  }

  Future<void> _loadMoments() async {
    await Provider.of<MomentProvider>(context, listen: false).loadMoments();
  }

  // 显示日期选择器
  Future<void> _showDatePicker(BuildContext context) async {
    final momentProvider = Provider.of<MomentProvider>(context, listen: false);
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: momentProvider.selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale('zh'),
      helpText: '选择日期筛选动态',
      confirmText: '确定',
      cancelText: '取消',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      momentProvider.filterByDate(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '朋友圈',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // 日历筛选按钮
          Consumer<MomentProvider>(
            builder: (ctx, momentProvider, _) {
              return IconButton(
                icon: Icon(
                  Icons.calendar_month,
                  color:
                      momentProvider.isFiltering ? Colors.blue : Colors.black,
                ),
                onPressed: () => _showDatePicker(context),
                tooltip: '按日期筛选',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMoments,
        child: Column(
          children: [
            // 显示筛选状态
            Consumer<MomentProvider>(
              builder: (ctx, momentProvider, _) {
                if (!momentProvider.isFiltering) {
                  return const SizedBox.shrink();
                }

                final dateStr = DateFormat('yyyy年MM月dd日')
                    .format(momentProvider.selectedDate!);

                return Container(
                  color: Colors.blue.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '当前显示 $dateStr 的动态',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          momentProvider.clearDateFilter();
                        },
                        child: const Row(
                          children: [
                            Text(
                              '清除筛选',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.close, size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // 动态列表
            Expanded(
              child: Consumer<MomentProvider>(
                builder: (ctx, momentProvider, child) {
                  if (momentProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (momentProvider.moments.isEmpty) {
                    if (momentProvider.isFiltering) {
                      // 筛选状态下无内容显示
                      final dateStr = DateFormat('yyyy年MM月dd日')
                          .format(momentProvider.selectedDate!);
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$dateStr 没有动态内容',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('查看全部动态'),
                              onPressed: () {
                                momentProvider.clearDateFilter();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                                backgroundColor: Colors.blue.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 正常状态下无内容
                    return const Center(
                      child: Text('暂无朋友圈动态，点击右下角发布新动态'),
                    );
                  }

                  return ListView.builder(
                    itemCount: momentProvider.moments.length,
                    itemBuilder: (ctx, index) {
                      final moment = momentProvider.moments[index];
                      return MomentCard(moment: moment);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 搜索按钮
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton(
                heroTag: 'search',
                backgroundColor: Colors.blue,
                child: const Icon(Icons.search),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SearchScreen(),
                    ),
                  );
                },
              ),
            ),
            // 相机按钮
            FloatingActionButton(
              heroTag: 'camera',
              backgroundColor: Colors.green,
              child: const Icon(Icons.camera_alt),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NewMomentScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
