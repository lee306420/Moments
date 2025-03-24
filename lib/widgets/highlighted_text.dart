import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 高亮显示搜索关键词的文本组件
class HighlightedText extends StatelessWidget {
  final String text;
  final String highlightText;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final bool caseSensitive;
  final bool highlightAll; // 是否高亮所有匹配项
  final int maxLines;
  final TextOverflow overflow;

  const HighlightedText({
    Key? key,
    required this.text,
    required this.highlightText,
    this.style,
    this.highlightStyle,
    this.caseSensitive = false,
    this.highlightAll = true,
    this.maxLines = 3,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (highlightText.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final defaultHighlightStyle = highlightStyle ??
        TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.red,
          backgroundColor: Colors.yellow.withOpacity(0.3),
        );

    final List<TextSpan> spans = [];
    final String sourceText = caseSensitive ? text : text.toLowerCase();

    // 将搜索词分割为单独的关键词
    final List<String> keywords = highlightText
        .split(' ')
        .where((keyword) => keyword.trim().isNotEmpty)
        .toList();

    // 如果没有有效关键词，则直接返回原文本
    if (keywords.isEmpty) {
      return Text(
        text,
        style: defaultStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // 转换关键词为小写（如果不区分大小写）
    final List<String> processedKeywords = keywords.map((keyword) {
      return caseSensitive ? keyword : keyword.toLowerCase();
    }).toList();

    // 标记哪些位置需要高亮
    List<_HighlightSpan> highlightSpans = [];

    // 找出所有关键词的匹配位置
    for (String keyword in processedKeywords) {
      int startIndex = 0;
      while (true) {
        final int index = sourceText.indexOf(keyword, startIndex);
        if (index == -1) break;

        // 添加匹配区间
        highlightSpans.add(_HighlightSpan(
          start: index,
          end: index + keyword.length,
        ));

        // 更新起始位置，继续搜索后面的匹配项
        startIndex = index + 1;

        // 如果只高亮第一个匹配项，则退出循环
        if (!highlightAll) break;
      }
    }

    // 合并重叠的高亮区间
    highlightSpans = _mergeOverlappingSpans(highlightSpans);

    // 按照区间起始位置排序
    highlightSpans.sort((a, b) => a.start - b.start);

    // 如果没有匹配项，直接返回原文本
    if (highlightSpans.isEmpty) {
      return Text(
        text,
        style: defaultStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // 构建富文本
    int currentIndex = 0;
    for (final span in highlightSpans) {
      // 添加前面不需要高亮的部分
      if (span.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, span.start),
          style: defaultStyle,
        ));
      }

      // 添加高亮部分
      spans.add(TextSpan(
        text: text.substring(span.start, span.end),
        style: defaultHighlightStyle,
      ));

      currentIndex = span.end;
    }

    // 添加最后一部分不需要高亮的文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: defaultStyle,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// 合并重叠的高亮区间
  List<_HighlightSpan> _mergeOverlappingSpans(List<_HighlightSpan> spans) {
    if (spans.isEmpty) return [];

    // 先按起始位置排序
    spans.sort((a, b) => a.start - b.start);

    List<_HighlightSpan> result = [];
    _HighlightSpan current = spans.first;

    for (int i = 1; i < spans.length; i++) {
      final next = spans[i];

      // 如果当前区间的结束位置大于等于下一个区间的开始位置，说明有重叠
      if (current.end >= next.start) {
        // 合并两个区间
        current = _HighlightSpan(
          start: current.start,
          end: math.max(current.end, next.end),
        );
      } else {
        // 无重叠，将当前区间添加到结果中
        result.add(current);
        current = next;
      }
    }

    // 添加最后一个区间
    result.add(current);

    return result;
  }
}

/// 表示需要高亮的文本区间
class _HighlightSpan {
  final int start;
  final int end;

  _HighlightSpan({
    required this.start,
    required this.end,
  });
}
