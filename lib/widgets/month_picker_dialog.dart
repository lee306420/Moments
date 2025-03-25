import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 自定义月份选择器对话框
class MonthPickerDialog extends StatefulWidget {
  /// 初始选择的日期
  final DateTime initialDate;

  /// 最早可选择的日期
  final DateTime firstDate;

  /// 最晚可选择的日期
  final DateTime lastDate;

  const MonthPickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();

  /// 显示月份选择器对话框
  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => MonthPickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late DateTime _selectedDate;
  late int _currentYear;
  final List<String> _months = [
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentYear = _selectedDate.year;
  }

  bool _isYearInRange(int year) {
    return year >= widget.firstDate.year && year <= widget.lastDate.year;
  }

  bool _isMonthInRange(int year, int month) {
    if (year == widget.firstDate.year && month < widget.firstDate.month) {
      return false;
    }
    if (year == widget.lastDate.year && month > widget.lastDate.month) {
      return false;
    }
    return true;
  }

  void _selectYear(int year) {
    if (_isYearInRange(year)) {
      setState(() {
        _currentYear = year;
        // 调整选中的日期，确保在允许范围内
        if (_selectedDate.year != year ||
            !_isMonthInRange(year, _selectedDate.month)) {
          if (year == widget.firstDate.year) {
            _selectedDate = DateTime(year, widget.firstDate.month, 1);
          } else if (year == widget.lastDate.year) {
            _selectedDate = DateTime(year, widget.lastDate.month, 1);
          } else {
            _selectedDate = DateTime(year, _selectedDate.month, 1);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 构建年份选择器
    Widget buildYearSelector() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left),
            onPressed: _isYearInRange(_currentYear - 1)
                ? () => _selectYear(_currentYear - 1)
                : null,
          ),
          GestureDetector(
            onTap: () => _showYearPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentYear年',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right),
            onPressed: _isYearInRange(_currentYear + 1)
                ? () => _selectYear(_currentYear + 1)
                : null,
          ),
        ],
      );
    }

    // 构建月份网格
    Widget buildMonthGrid() {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final month = index + 1; // 月份从1开始
          final isSelected = _selectedDate.year == _currentYear &&
              _selectedDate.month == month;
          final isInRange = _isMonthInRange(_currentYear, month);

          final monthDate = DateTime(_currentYear, month, 1);
          final monthName = _months[index];
          final formattedMonth = DateFormat('MM').format(monthDate);

          return InkWell(
            onTap: isInRange
                ? () {
                    setState(() {
                      _selectedDate = DateTime(_currentYear, month, 1);
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : isInRange
                        ? Colors.white
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isInRange
                              ? Colors.black87
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedMonth,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : isInRange
                              ? Colors.black54
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '选择月份',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const Divider(),
            buildYearSelector(),
            const SizedBox(height: 16),
            buildMonthGrid(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        final firstYear = widget.firstDate.year;
        final lastYear = widget.lastDate.year;
        final int yearsCount = lastYear - firstYear + 1;

        return AlertDialog(
          title: const Text('选择年份'),
          content: SizedBox(
            width: 300,
            height: 300.0,
            child: ListView.builder(
              itemCount: yearsCount,
              itemBuilder: (context, index) {
                final year = firstYear + index;
                final isSelected = year == _currentYear;

                return ListTile(
                  title: Text(
                    '$year年',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    _selectYear(year);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
