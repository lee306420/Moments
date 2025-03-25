import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/moment_provider.dart';
import '../widgets/moment_card.dart';
import '../widgets/month_picker_dialog.dart';
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

  // 显示月份选择器
  Future<void> _showMonthPicker(BuildContext context) async {
    final momentProvider = Provider.of<MomentProvider>(context, listen: false);
    final DateTime now = DateTime.now();
    final DateTime initialDate = momentProvider.selectedMonth ?? now;

    // 使用自定义月份选择器
    final DateTime? pickedDate = await MonthPickerDialog.show(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (pickedDate != null) {
      momentProvider.filterByMonth(pickedDate);
    }
  }

  // 显示筛选选项对话框
  void _showFilterOptions(BuildContext context) {
    final momentProvider = Provider.of<MomentProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '选择筛选方式',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('按日期筛选'),
                subtitle: const Text('查看特定日期发布的动态'),
                onTap: () {
                  Navigator.pop(context);
                  _showDatePicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range, color: Colors.green),
                title: const Text('按月份筛选'),
                subtitle: const Text('查看整个月份发布的动态'),
                onTap: () {
                  Navigator.pop(context);
                  _showMonthPicker(context);
                },
              ),
              if (momentProvider.isFiltering || momentProvider.isMonthFiltering)
                ListTile(
                  leading: const Icon(Icons.clear_all, color: Colors.red),
                  title: const Text('清除所有筛选'),
                  onTap: () {
                    Navigator.pop(context);
                    momentProvider.clearAllFilters();
                  },
                ),
            ],
          ),
        );
      },
    );
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
                  Icons.filter_alt,
                  color: (momentProvider.isFiltering ||
                          momentProvider.isMonthFiltering)
                      ? Colors.blue
                      : Colors.black,
                ),
                onPressed: () => _showFilterOptions(context),
                tooltip: '筛选动态',
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
                if (!momentProvider.isFiltering &&
                    !momentProvider.isMonthFiltering) {
                  return const SizedBox.shrink();
                }

                String filterInfo = '';
                Color backgroundColor = Colors.blue.shade50;
                IconData iconData = Icons.calendar_today;

                if (momentProvider.isFiltering) {
                  final dateStr = DateFormat('yyyy年MM月dd日')
                      .format(momentProvider.selectedDate!);
                  filterInfo = '当前显示 $dateStr 的动态';
                } else if (momentProvider.isMonthFiltering) {
                  final monthStr = DateFormat('yyyy年MM月')
                      .format(momentProvider.selectedMonth!);
                  filterInfo = '当前显示 $monthStr 的动态';
                  backgroundColor = Colors.green.shade50;
                  iconData = Icons.date_range;
                }

                return Container(
                  color: backgroundColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(iconData,
                          size: 16,
                          color: momentProvider.isFiltering
                              ? Colors.blue
                              : Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filterInfo,
                          style: TextStyle(
                            color: momentProvider.isFiltering
                                ? Colors.blue
                                : Colors.green,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (momentProvider.isFiltering) {
                            momentProvider.clearDateFilter();
                          } else if (momentProvider.isMonthFiltering) {
                            momentProvider.clearMonthFilter();
                          }
                        },
                        child: Row(
                          children: [
                            Text(
                              '清除筛选',
                              style: TextStyle(
                                color: momentProvider.isFiltering
                                    ? Colors.blue
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.close,
                              size: 16,
                              color: momentProvider.isFiltering
                                  ? Colors.blue
                                  : Colors.green,
                            ),
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
                    if (momentProvider.isFiltering ||
                        momentProvider.isMonthFiltering) {
                      // 筛选状态下无内容显示
                      String dateInfo = '';
                      IconData iconData = Icons.calendar_today;
                      Color iconColor = Colors.blue;

                      if (momentProvider.isFiltering) {
                        dateInfo = DateFormat('yyyy年MM月dd日')
                            .format(momentProvider.selectedDate!);
                      } else {
                        dateInfo = DateFormat('yyyy年MM月')
                            .format(momentProvider.selectedMonth!);
                        iconData = Icons.date_range;
                        iconColor = Colors.green;
                      }

                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              iconData,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$dateInfo 没有动态内容',
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
                                momentProvider.clearAllFilters();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: iconColor,
                                backgroundColor: iconColor.withOpacity(0.1),
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
