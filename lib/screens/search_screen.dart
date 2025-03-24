import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../models/moment.dart';
import '../widgets/moment_card.dart';
import '../widgets/search_result_card.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  List<Moment> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isLoadingHistory = true;
  bool _searchInContent = true;
  bool _searchInComments = true;
  bool _sortByRelevance = true;

  // 添加动画控制器
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 搜索防抖计时器
  Timer? _debounceTimer;

  // 显示过滤器面板
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();

    // 初始化搜索服务
    _initSearchService();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      await _searchService.init();
      final history = await _searchService.getSearchHistory();

      setState(() {
        _searchHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载搜索历史出错: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      await _searchService.clearHistory();
      setState(() {
        _searchHistory = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('搜索历史已清空'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清空搜索历史出错: $e'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _removeHistoryItem(String query) async {
    try {
      await _searchService.removeHistoryItem(query);
      setState(() {
        _searchHistory.removeWhere((item) => item == query);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除历史记录失败: $e'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _initSearchService() async {
    try {
      await _searchService.init();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化搜索服务出错: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 确保搜索服务已初始化
      await _searchService.init();

      final results = await _searchService.searchMoments(
        query: _searchController.text.trim(),
        searchInContent: _searchInContent,
        searchInAuthor: false, // 不再搜索作者
        searchInComments: _searchInComments,
        sortByRelevance: _sortByRelevance,
      );

      // 检查挂载状态防止内存泄漏
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });

        // 刷新搜索历史
        _loadSearchHistory();

        // 调试输出
        print('搜索完成：找到 ${results.length} 条结果');
      }
    } catch (e) {
      print('搜索出错: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索时出错: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearchBar(),
              if (_showFilterPanel) _buildExpandedFilterPanel(),
              Expanded(
                child: FadeTransition(
                  opacity: _animation,
                  child: _buildSearchContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            '搜索',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showFilterPanel ? Icons.tune : Icons.tune_outlined,
              color: _showFilterPanel ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _showFilterPanel = !_showFilterPanel;
              });
              // 如果有搜索内容，切换过滤面板时自动刷新搜索结果
              if (_searchController.text.isNotEmpty) {
                _performSearch();
              }
            },
            tooltip: '搜索选项',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '输入搜索关键词...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(
              _isSearching ? Icons.search : Icons.search,
              color: _isSearching ? Colors.blue : Colors.blue.shade300,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            suffixIcon: _searchController.text.isNotEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue.shade300,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      ),
                    ],
                  )
                : null,
          ),
          onSubmitted: (_) => _performSearch(),
          onChanged: (value) {
            setState(() {}); // 更新UI以显示或隐藏清除按钮

            // 防抖搜索，避免频繁搜索
            if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

            if (value.isEmpty) {
              setState(() {
                _searchResults = [];
              });
              return;
            }

            // 字符数小于等于1时，使用更短的延迟
            final delay = value.length <= 1 ? 300 : 150;

            _debounceTimer = Timer(Duration(milliseconds: delay), () {
              if (value.length >= 1) {
                // 降低了触发搜索的字符数门槛，只要输入1个字符就开始搜索
                _performSearch();
              }
            });
          },
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16),
          autofocus: true, // 自动获取焦点，方便用户直接输入
        ),
      ),
    );
  }

  Widget _buildExpandedFilterPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '搜索范围',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFilterChip(
                label: '内容',
                icon: Icons.subject,
                selected: _searchInContent,
                onSelected: (selected) {
                  setState(() {
                    _searchInContent = selected;
                  });
                  if (_searchController.text.isNotEmpty) {
                    _performSearch();
                  }
                },
              ),
              _buildFilterChip(
                label: '评论',
                icon: Icons.comment,
                selected: _searchInComments,
                onSelected: (selected) {
                  setState(() {
                    _searchInComments = selected;
                  });
                  if (_searchController.text.isNotEmpty) {
                    _performSearch();
                  }
                },
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            '排序方式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSortOption(
                  label: '按相关度',
                  icon: Icons.sort,
                  selected: _sortByRelevance,
                  onTap: () {
                    setState(() {
                      _sortByRelevance = true;
                    });
                    if (_searchController.text.isNotEmpty) {
                      _performSearch();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSortOption(
                  label: '按时间',
                  icon: Icons.history,
                  selected: !_sortByRelevance,
                  onTap: () {
                    setState(() {
                      _sortByRelevance = false;
                    });
                    if (_searchController.text.isNotEmpty) {
                      _performSearch();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.blue : Colors.grey.shade300,
        ),
      ),
      elevation: selected ? 1 : 0,
      pressElevation: 2,
    );
  }

  Widget _buildSortOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.blue : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在搜索...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    } else if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    } else if (_searchController.text.isNotEmpty) {
      return _buildNoResults();
    } else {
      return _buildSearchHistorySection();
    }
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                '搜索结果 (${_searchResults.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (!_showFilterPanel)
                Row(
                  children: [
                    Text(
                      '排序: ',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _sortByRelevance = !_sortByRelevance;
                          _performSearch();
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Text(
                              _sortByRelevance ? '相关度' : '时间',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.swap_vert,
                                size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              // 为列表项添加动画效果
              return AnimatedOpacity(
                opacity: 1.0,
                duration: Duration(milliseconds: 300 + (index * 30)),
                child: SearchResultCard(
                  moment: _searchResults[index],
                  searchQuery: _searchController.text.trim(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的结果',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用不同的关键词或搜索范围',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('调整搜索选项'),
            onPressed: () {
              setState(() {
                _showFilterPanel = true;
              });
              // 如果有搜索内容，打开过滤面板时自动刷新搜索结果
              if (_searchController.text.isNotEmpty) {
                _performSearch();
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              foregroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistorySection() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '没有搜索历史记录',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '您的搜索记录将显示在这里',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                label: const Text('清空', style: TextStyle(color: Colors.red)),
                onPressed: _clearSearchHistory,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              return Dismissible(
                key: Key(_searchHistory[index]),
                background: Container(
                  color: Colors.red.shade100,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _removeHistoryItem(_searchHistory[index]);
                },
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text(
                    _searchHistory[index],
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.north_west,
                      size: 16, color: Colors.grey),
                  onTap: () {
                    _searchController.text = _searchHistory[index];
                    _performSearch();
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
